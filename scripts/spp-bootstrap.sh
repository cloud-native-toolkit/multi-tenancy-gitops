#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

check_prereqs() {
    ##############################################################################
    # Begin environment checking
    ##############################################################################
    
    error=0
    command -v helm >/dev/null 2>&1 || { echo >&2 "The helm V3 CLI is required but it's not installed. See https://helm.sh/docs/intro/install/ "; error=$(( $error + 1 )); }
    command -v dig > /dev/null 2>&1 || { echo >&2 "The dig command is required but it's not found."; error=$(( $error + 1 )); }
    command -v jq > /dev/null 2>&1 || { echo >&2 "The jq command is required but it's not installed. See https://stedolan.github.io/jq/"; error=$(( $error + 1 )); }
    command -v yq > /dev/null 2>&1 || { echo >&2 "The yq command is required but it's not installed. See https://mikefarah.gitbook.io/yq/"; error=$(( $error + 1 )); }
    command -v git > /dev/null 2>&1 || { echo >&2 "The git command is required but it's not installed. See https://git-scm.com/downloads"; error=$(( $error + 1 )); }
    command -v gh >/dev/null 2>&1 || { echo >&2 "The Github CLI gh is required but it's not installed. Download https://github.com/cli/cli "; error=$(( $error + 1 )); }
    
    if [[ ${error} -gt 0 ]]; then
      exit ${error}
    fi

    error=0
    set +e
    oc version --client | grep '4.7\|4.8'
    OC_VERSION_CHECK=$?
    # set -x
    if [[ ${OC_VERSION_CHECK} -ne 0 ]]; then
        echo "Please use oc client version 4.7 or 4.8 download from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/ "
    fi
    
    git -C ${SCRIPTDIR} rev-parse 2>/dev/null
    if [ "$?" -eq 0 ]; then
        echo "GIT check OK"
    else
        echo "the script must be run from under a Git repository"
        error=$(( $error + 1 ))
    fi
    
    gh_stat=$(gh auth status 2>&1 | grep "not logged" | wc -l)
    if [[ "${gh_stat}" -gt "0" ]]; then
        echo "Not logged into GitHub gh cli"
        error=$(( $error + 1 ))
    else
        echo "Github gh is active"
    fi
    
    oc_ready=$(oc whoami 2>&1 | grep Error | wc -l)
    if [[ "${oc_ready}" -gt 0 ]]; then
        echo "Not logged into OpenShift cli"
        error=$(( $error + 1 ))
    else
        echo "OpenShift is on "
    fi
    
    helmver=$(helm version --client 2>&1 | grep Version | grep v3 | wc -l)
    if [[ "${helmver}" -eq 0 ]]; then
        echo "Helm must be v3"
        error=$(( $error + 1 ))
    else
        echo "Helm is v3"
        
    fi
    
    sscount=$(oc get pod -n sealed-secrets | grep sealed-secret | wc -l)
    if [[ "${sscount}" -eq 0 ]]; then
        echo "Sealed secret is not installed"
        error=$(( $error + 1 ))
    else
        echo "Sealed secret pod is running"
    fi

    if [[ -z $IBM_ENTITLEMENT_KEY ]]; then
        echo "Please supply IBM_ENTITLEMENT_KEY"
        error=$(( $error + 1 )) 
    fi
    set -e

    if [[ ${error} -gt 0 ]]; then
      exit ${error}
    fi

    ##############################################################################
    # End environment checking
    ##############################################################################
}

collect_info() {
    ##############################################################################
    # Start collecting cluster information
    ##############################################################################
    #set -x
    CLUSTER_DOMAIN=$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }')
    DEFSC=$(oc get sc --no-headers | grep "(default)" | cut -d" " -f 1)
    STORCLASS=${STORCLASS:-${DEFSC}}
    
    if [[ "${STORCLASS}" == "" ]]; then
        echo "No default StorageClass defined - please specify the default storage class or set \$STORCLASS variable"
        exit 1
    fi
    
    ADMINUSER=${ADMINUSER:-sppadmin}
    ADMINPW=${ADMINPW:-passw0rd}
    CLUSTER_NAME=$(oc get cm cluster-config-v1 -n kube-system -o jsonpath='{.data.install-config}' | yq -r .metadata.name )
    SPPFQDN=${SPPFQDN:-"ibmspp.apps.${CLUSTER_DOMAIN}"}
    SPPIP=$(dig +short ${SPPFQDN})
    BAASID=${BAASID:-${CLUSTER_NAME}}
    BAAS_VERSION=${BAAS_VERSION:-'10.1.8.2'}
    BAAS_HELM_VERSION=${BAAS_HELM_VERSION:-'1.2.2'}
    
    
    IPS=( $(oc get endpoints -n default -o yaml kubernetes | yq '.subsets[0].addresses ' | jq .[].ip -r ) )
    CIDR=$(oc get network cluster -o yaml | yq .spec.clusterNetwork[0].cidr -r)
    
    ##############################################################################
    # End collecting cluster information
    ##############################################################################
}

build_spp_instance() {
    pushd ${SCRIPTDIR}/../0-bootstrap/single-cluster/2-services/argocd/instances
    # Editing spp-instance.yaml
    oc get packagemanifest -n openshift-marketplace spp-operator -o yaml | \
      yq '.status.channels[0].currentCSVDesc.annotations."alm-examples"' -r | \
      jq .[] | yq -y | \
      sed "s/image_pull_secret: ibm-spp/image_pull_secret: ibmspp-image-secret/g" | \
      sed "s/accept: false/accept: true/g" | \
      sed "s/hostname: spp/hostname: ibmspp.apps.${CLUSTER_DOMAIN}/g" | \
      sed "s/storage_class_name: standard/storage_class_name: ${STORCLASS}/g" | \
      sed -n '/^spec:/,$p' | \
      sed 's/^/            /'> ibmspp.y1
    cat spp-instance.yaml | sed -n '/^            spec:/q;p' | sed '/^$/d' > ibmspp.y0
    cat spp-instance.yaml | sed -n '/^            spec:/q;p' | sed '/^$/d' > ibmspp.y0
    echo "        ibmsppsecret:" > ibmspp.y2
    echo "          data:" >> ibmspp.y2
    oc create secret docker-registry ibmspp-image-secret \
      --docker-username=cp \
      --docker-server="cp.icr.io/cp/sppserver" \
      --docker-password=${IBM_ENTITLEMENT_KEY} \
      --docker-email="${ADMINUSER}@us.ibm.com" \
      -n spp --dry-run=client -o yaml > tmp-secret.yaml
    kubeseal --scope cluster-wide --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml < tmp-secret.yaml | \
      sed -n '/^  encryptedData:/,$p' | sed -n '/^  template:/q;p' | \
      grep -v "encryptedData:" | sed 's/^/        /g' >> ibmspp.y2

    cat ibmspp.y0  ibmspp.y1 ibmspp.y2 > spp-instance.yaml
    rm ibmspp.* tmp-secret.yaml
    popd
}

build_baas() {
    pushd ${SCRIPTDIR}/../0-bootstrap/single-cluster/2-services/argocd/instances
    #curl -kLo ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm/ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz
    #tar -xzf ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz   
    #rm ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz
    #rm -rf ibm-spectrum-protect-plus-prod
    #cp ibm-spectrum-protect-plus-prod/ibm_cloud_pak/pak_extensions/crds/baas.io_baasreqs_crd.yaml .
        
    cat baas-instance.yaml | sed -n '/^          baassecret:/q;p' | sed '/^$/d' > baas.00

    cat - > baas.01 << EOF
          baassecret:
            data:
EOF

    oc create secret generic baas-secret --dry-run=client -o yaml --namespace baas \
        --from-literal='baasadmin='"${ADMINUSER}"'' \
        --from-literal='baaspassword='"${ADMINPW}"'' \
        --from-literal='datamoveruser='"${ADMINUSER}"'' \
        --from-literal='datamoverpassword='"${ADMINPW}"'' \
        --from-literal='miniouser='"${ADMINUSER}"'' \
        --from-literal='miniopassword='"${ADMINPW}"'' > tmp-baas-secret.yaml
    kubeseal --scope cluster-wide --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml < tmp-baas-secret.yaml > baas-secret.yaml
    cat baas-secret.yaml | sed -n '/^  encryptedData:/,$p' | sed -n '/^  template:/q;p' | grep -v "encryptedData:" | sed 's/^/          /g' > baas.02

    cat - > baas.03 << EOF
          baasregistrysecret:
            data:
EOF

    oc create secret docker-registry baas-registry-secret \
        --docker-username=cp \
        --docker-server="cp.icr.io/cp" \
        --docker-password=${IBM_ENTITLEMENT_KEY} \
        --docker-email="spp@us.ibm.com" \
        -n baas --dry-run=client -o yaml > tmp-baas-registry-secret.yaml
    kubeseal --scope cluster-wide --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml < tmp-baas-registry-secret.yaml > baas-registry-secret.yaml
    cat baas-registry-secret.yaml | sed -n '/^  encryptedData:/,$p' | sed -n '/^  template:/q;p' | grep -v "encryptedData:" | sed 's/^/          /g' > baas.04

    cat - > baas.05 << EOF
        ibm-spectrum-protect-plus-prod:
EOF

    cat - > baas-values.yaml << EOF
    license: true
    isOCP: true
    clusterName: ${BAASID}
    networkPolicy:
      clusterAPIServerips:
        - ${IPS[0]}
        - ${IPS[1]}
        - ${IPS[2]}
      clusterAPIServerport: 6443
      clusterCIDR: ${CIDR}
      isServerInstalledOnAnotherCluster: false
    SPPfqdn: ${SPPFQDN}
    SPPips: ${SPPIP}
    SPPport: 443
    productLoglevel: INFO
    imageRegistry: cp.icr.io/cp
    imageRegistryNamespace: sppc
    minioStorageClass: ${STORCLASS}
    veleroNamespace: spp-velero
EOF

    cat baas-values.yaml | sed 's/^/      /g' > baas.06

    cat baas.00 baas.01 baas.02 baas.03 baas.04 baas.05 baas.06 > baas.all
    rm tmp-baas-secret.yaml tmp-baas-registry-secret.yaml baas-secret.yaml baas-registry-secret.yaml
    rm baas.0* baas-values.yaml baas-instance.yaml
    mv baas.all baas-instance.yaml
}

check_prereqs

collect_info

build_spp_instance

build_baas
