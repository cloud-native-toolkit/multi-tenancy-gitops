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

display_help () {
    echo "This baas-instance.sh configures the baas-instance.yaml"
    echo "See https://github.com/cloud-native-toolkit/multi-tenancy-gitops for more information"
    echo ""
    echo "The following environment variables are required:"
    echo "IBM_ENTITLEMENT_KEY - IBM Container registry entitlement key"
    echo ""
    echo "The following environment variables are optional:"
    echo "SPPUSER             - Spectrum Protect plus user name - default to \${ADMINUSER}"
    echo "SPPPW               - Spectrum Protect plus password - default to \${ADMINPW}"
    echo "ADMINUSER           - BaaS administrator user - default to sppadmin" 
    echo "ADMINPW             - BaaS administrator password - default to passw0rd" 
    echo "SPPFQDN             - Spectrum Protect Plus server host - default to ibmspp.apps.\${CLUSTER_DOMAIN}"
    echo ""
    echo "Required CLIs: bash, helm, dig, jq, yq, git, gh, oc" 
    exit 1
}

check_prereqs() {
    ##############################################################################
    # Begin environment checking
    ##############################################################################
    echo "Checking prerequisites"
    error=0
    command -v helm >/dev/null 2>&1 || { echo >&2 "ERROR: The helm V3 CLI is required but it's not installed. See https://helm.sh/docs/intro/install/ "; error=$(( $error + 1 )); }
    command -v dig > /dev/null 2>&1 || { echo >&2 "ERROR: The dig command is required but it's not found."; error=$(( $error + 1 )); }
    command -v jq > /dev/null 2>&1 || { echo >&2 "ERROR: The jq command is required but it's not installed. See https://stedolan.github.io/jq/"; error=$(( $error + 1 )); }
    command -v yq > /dev/null 2>&1 || { echo >&2 "ERROR: The yq command is required but it's not installed. See https://mikefarah.gitbook.io/yq/"; error=$(( $error + 1 )); }
    command -v oc >/dev/null 2>&1 || { echo >&2 "ERROR: The oc is required but it's not installed. Download https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/ "; error=$(( $error + 1 )); }
    
    if [[ ${error} -gt 0 ]]; then
      exit ${error}
    fi

    error=0
    set +e
    oc version --client | grep '4.7\|4.8'
    OC_VERSION_CHECK=$?
    # set -x
    if [[ ${OC_VERSION_CHECK} -ne 0 ]]; then
        echo "WARN: Please use oc client version 4.7 or 4.8 download from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/ "
    fi
    
    oc_ready=$(oc whoami 2>&1 | grep Error | wc -l)
    if [[ "${oc_ready}" -gt 0 ]]; then
        echo >&2 "ERROR: Not logged into an OpenShift environment cli"
        error=$(( $error + 1 ))
    fi
    
    helmver=$(helm version --client 2>&1 | grep Version | grep v3 | wc -l)
    if [[ "${helmver}" -eq 0 ]]; then
        echo >&2 "ERROR: Helm must be v3"
        error=$(( $error + 1 ))
    fi
    
    if [[ -z $IBM_ENTITLEMENT_KEY ]]; then
        echo >&2 "ERROR: Please supply IBM_ENTITLEMENT_KEY"
        error=$(( $error + 1 )) 
    fi

    sscount=$(oc get pod -n sealed-secrets | grep sealed-secret | wc -l)
    if [[ "${sscount}" -eq 0 ]]; then
        echo >&2 "ERROR: Sealed secret is not installed - please enable sealed-secret.yaml"
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
    SPPUSER=${SPPUSER:-${ADMINUSER}}
    SPPPW=${SPPPW:-${ADMINPW}}
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

build_baas () {
    pushd ${SCRIPTDIR}/../0-bootstrap/single-cluster/2-services/argocd/instances
    #curl -kLo ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm/ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz
    #tar -xzf ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz   
    #rm ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz
    #rm -rf ibm-spectrum-protect-plus-prod
    #cp ibm-spectrum-protect-plus-prod/ibm_cloud_pak/pak_extensions/crds/baas.io_baasreqs_crd.yaml .
    echo "Working on 0-bootstrap/single-cluster/2-services/argocd/instances/baas-instance.yaml"
    cat baas-instance.yaml | sed -n '/^          baassecret:/q;p' | sed '/^$/d' > baas.00

    cat - > baas.01 << EOF
          baassecret:
            data:
EOF
    oc create secret generic baas-secret --dry-run=client -o yaml --namespace baas \
        --from-literal='baasadmin='"${SPPUSER}"'' \
        --from-literal='baaspassword='"${SPPPW}"'' \
        --from-literal='datamoveruser='"${ADMINUSER}"'' \
        --from-literal='datamoverpassword='"${ADMINPW}"'' \
        --from-literal='miniouser='"${ADMINUSER}"'' \
        --from-literal='miniopassword='"${ADMINPW}"'' > tmp-baas-secret.yaml
    kubeseal --scope cluster-wide --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml < tmp-baas-secret.yaml | \
      sed -n '/^  encryptedData:/,$p' | \
      sed -n '/^  template:/q;p' | \
      grep -v "encryptedData:" | \
      sed 's/^/          /g' >> baas.01

    cat - > baas.02 << EOF
          baasregistrysecret:
            data:
EOF
    oc create secret docker-registry baas-registry-secret \
        --docker-username=cp \
        --docker-server="cp.icr.io/cp" \
        --docker-password=${IBM_ENTITLEMENT_KEY} \
        --docker-email="spp@us.ibm.com" \
        -n baas --dry-run=client -o yaml > tmp-baas-registry-secret.yaml
    kubeseal --scope cluster-wide --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml < tmp-baas-registry-secret.yaml | \
      sed -n '/^  encryptedData:/,$p' | \
      sed -n '/^  template:/q;p' | \
      grep -v "encryptedData:" | \
      sed 's/^/          /g' >> baas.02

    cat - > baas.03 << EOF
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
    tm:
      replicaCount: 3
EOF

    cat baas-values.yaml | sed 's/^/      /g' >> baas.03

    cat baas.00 baas.01 baas.02 baas.03 > baas.all
    rm tmp-baas-secret.yaml tmp-baas-registry-secret.yaml 
    rm baas.0* baas-values.yaml baas-instance.yaml
    mv baas.all baas-instance.yaml

    echo "BAAS instance configured - Please Commit and Push your changes to GIT"
}

[ "$1" = "-h" -o "$1" = "--help"  -o "$1" = "-?" ] && display_help 

check_prereqs

collect_info

build_baas
