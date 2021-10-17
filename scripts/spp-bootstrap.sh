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
    echo "This spp-bootstrap.sh deploy IBM Spectrum Protect Plus in an environment from Production Deployment Guide gitops"
    echo "See https://github.com/cloud-native-toolkit/multi-tenancy-gitops for more information"
    echo ""
    echo "The following environment variables are required:"
    echo "IBM_ENTITLEMENT_KEY - IBM Container registry entitlement key"
    echo ""
    echo "The following environment variables are optional:"
    echo "DEPLOYSPP           - Whether to deploy SPP server - default to true"
    echo "DEPLOYBAAS          - Whether to deploy baas - default to true"
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
    
    error=0
    command -v helm >/dev/null 2>&1 || { echo >&2 "ERROR: The helm V3 CLI is required but it's not installed. See https://helm.sh/docs/intro/install/ "; error=$(( $error + 1 )); }
    command -v dig > /dev/null 2>&1 || { echo >&2 "ERROR: The dig command is required but it's not found."; error=$(( $error + 1 )); }
    command -v jq > /dev/null 2>&1 || { echo >&2 "ERROR: The jq command is required but it's not installed. See https://stedolan.github.io/jq/"; error=$(( $error + 1 )); }
    command -v yq > /dev/null 2>&1 || { echo >&2 "ERROR: The yq command is required but it's not installed. See https://mikefarah.gitbook.io/yq/"; error=$(( $error + 1 )); }
    command -v git > /dev/null 2>&1 || { echo >&2 "ERROR: The git command is required but it's not installed. See https://git-scm.com/downloads"; error=$(( $error + 1 )); }
    command -v gh >/dev/null 2>&1 || { echo >&2 "ERROR: The Github CLI gh is required but it's not installed. Download https://github.com/cli/cli "; error=$(( $error + 1 )); }
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
    
    git -C ${SCRIPTDIR} rev-parse 2>/dev/null
    if [ "$?" -eq 0 ]; then
        echo "GIT check OK"
    else
        echo >&2 "ERROR: The script must be run from under a Git repository"
        error=$(( $error + 1 ))
    fi
    
    gh_stat=$(gh auth status 2>&1 | grep "not logged" | wc -l)
    if [[ "${gh_stat}" -gt "0" ]]; then
        echo >&2 "ERROR: Not logged into GitHub gh cli"
        error=$(( $error + 1 ))
    else
        echo "Github gh is active"
    fi
    
    oc_ready=$(oc whoami 2>&1 | grep Error | wc -l)
    if [[ "${oc_ready}" -gt 0 ]]; then
        echo >&2 "ERROR: Not logged into an OpenShift environment cli"
        error=$(( $error + 1 ))
    else
        echo "OpenShift is on "
    fi
    
    helmver=$(helm version --client 2>&1 | grep Version | grep v3 | wc -l)
    if [[ "${helmver}" -eq 0 ]]; then
        echo >&2 "ERROR: Helm must be v3"
        error=$(( $error + 1 ))
    else
        echo "Helm is v3"
        
    fi
    
    if [[ -z $IBM_ENTITLEMENT_KEY ]]; then
        echo >&2 "ERROR: Please supply IBM_ENTITLEMENT_KEY"
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

enable_prereq_applications () {

    pushd "${SCRIPTDIR}/../0-bootstrap/single-cluster"
    set +e
    sscount=$(oc get pod -n sealed-secrets | grep sealed-secret | wc -l)
    if [[ "${sscount}" -eq 0 ]]; then
      sed -i.bak '/namespace-sealed-secrets.yaml/s/^#//g' 1-infra/kustomization.yaml
      sed -i.bak '/namespace-tools.yaml/s/^#//g' 1-infra/kustomization.yaml
      sed -i.bak '/sealed-secrets.yaml/s/^#//g' 2-services/kustomization.yaml
    fi

    sppoper=$(oc get packagemanifest -n openshift-marketplace spp-operator --no-headers 2>/dev/null | wc -l)
    if [[ "$sppoper" -eq 0 ]]; then
      sed -i.bak '/namespace-spp.yaml/s/^#//g' 1-infra/kustomization.yaml
      sed -i.bak '/spp-catalog.yaml/s/^#//g' 2-services/kustomization.yaml
    fi

    rm 1-infra/kustomization.yaml.bak
    rm 2-services/kustomization.yaml.bak
    # source ${SCRIPTDIR}/sync-manifests.sh
    git add ..
    git commit -m "Adding Spectrum Protect Plus prerequisites"
    git push origin
    popd

    echo -n "Waiting till Sealed Secret is available"
    sscount=$(oc get pod -n sealed-secrets | grep sealed-secret | wc -l)
    until [[ "$sscount" -gt 0 ]]; do
      sleep 20
      sscount=$(oc get pod -n sealed-secrets | grep sealed-secret | wc -l)
      echo -n "."
    done
    echo ". $(oc get pod -n sealed-secrets --no-headers)"

    echo -n "Waiting for SPP catalog is available"
    OUTPUT="INITIAL"
    until [ $OUTPUT = "READY" ]; do
      sleep 20
      OUTPUT=$(oc get -n openshift-marketplace catalogsource ibm-spp-operator -o custom-columns=stat:status.connectionState.lastObservedState --no-headers)
      echo -n "."
    done
    echo ". ${OUTPUT}"
    set -e

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
    DEPLOYSPP=${DEPLOYSPP:-true}
    DEPLOYBAAS=${DEPLOYBAAS:-true}
    
    
    IPS=( $(oc get endpoints -n default -o yaml kubernetes | yq '.subsets[0].addresses ' | jq .[].ip -r ) )
    CIDR=$(oc get network cluster -o yaml | yq .spec.clusterNetwork[0].cidr -r)
    
    ##############################################################################
    # End collecting cluster information
    ##############################################################################
}

build_spp_instance() {
    pushd ${SCRIPTDIR}/../0-bootstrap/single-cluster/2-services/argocd/instances
    # Editing spp-instance.yaml
    echo "Working on spp-instance.yaml"
    oc get packagemanifest -n openshift-marketplace spp-operator -o yaml | \
      yq '.status.channels[0].currentCSVDesc.annotations."alm-examples"' -r | \
      jq .[] | yq -y | \
      sed "s/image_pull_secret: ibm-spp/image_pull_secret: ibmspp-image-secret/g" | \
      sed "s/accept: false/accept: true/g" | \
      sed "s/hostname: spp/hostname: ${SPPFQDN}/g" | \
      sed "s# registry: ibm# registry: cp.icr.io/cp/sppserver#g" | \
      sed "s/storage_class_name: standard/storage_class_name: ${STORCLASS}/g" | \
      sed -n '/^spec:/,$p' | \
      sed 's/^/            /'> ibmspp.y1
    cat spp-instance.yaml | sed -n '/^            spec:/q;p' | sed '/^$/d' > ibmspp.y0
    echo "          ibmsppsecret:" > ibmspp.y2
    echo "            data:" >> ibmspp.y2
    oc create secret docker-registry ibmspp-image-secret \
      --docker-username=cp \
      --docker-server="cp.icr.io/cp/sppserver" \
      --docker-password=${IBM_ENTITLEMENT_KEY} \
      --docker-email="${SPPUSER}@us.ibm.com" \
      -n spp --dry-run=client -o yaml > tmp-secret.yaml
    kubeseal --scope cluster-wide --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml < tmp-secret.yaml | \
      sed -n '/^  encryptedData:/,$p' | sed -n '/^  template:/q;p' | \
      grep -v "encryptedData:" | sed 's/^/          /g' >> ibmspp.y2

    echo "          sppadmin:" > ibmspp.y3
    echo "            data:" >> ibmspp.y3
    oc create secret generic sppadmin --from-literal adminPassword=${SPPPW} --from-literal adminUser=${SPPUSER} --dry-run=client -n spp -o yaml > tmp-sppadmin.yaml
    kubeseal --scope cluster-wide --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml < tmp-sppadmin.yaml | \
      sed -n '/^  encryptedData:/,$p' | sed -n '/^  template:/q;p' | \
      grep -v "encryptedData:" | sed 's/^/          /g' >> ibmspp.y3
      
    cat ibmspp.y0  ibmspp.y1 ibmspp.y2 ibmspp.y3 > spp-instance.yaml
    rm ibmspp.* tmp-*.yaml
    echo "SPP instance configured"

    popd

    pushd ${SCRIPTDIR}/..
    sed -i.bak '/spp-operator.yaml/s/^#//g' 0-bootstrap/single-cluster/2-services/kustomization.yaml
    sed -i.bak '/spp-instance.yaml/s/^#//g' 0-bootstrap/single-cluster/2-services/kustomization.yaml
    sed -i.bak '/spp-postsync.yaml/s/^#//g' 0-bootstrap/single-cluster/2-services/kustomization.yaml
    rm 0-bootstrap/single-cluster/2-services/kustomization.yaml.bak
    git add .
    git commit -m "Adding Spectrum Protect Plus instance"
    git push origin
    popd
}

build_baas () {
    pushd ${SCRIPTDIR}/../0-bootstrap/single-cluster/2-services/argocd/instances
    #curl -kLo ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm/ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz
    #tar -xzf ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz   
    #rm ibm-spectrum-protect-plus-prod-${BAAS_HELM_VERSION}.tgz
    #rm -rf ibm-spectrum-protect-plus-prod
    #cp ibm-spectrum-protect-plus-prod/ibm_cloud_pak/pak_extensions/crds/baas.io_baasreqs_crd.yaml .
    echo "Working on baas-instance.yaml"
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

    pushd ${SCRIPTDIR}/..
    sed -i.bak '/namespace-spp-velero.yaml/s/^#//g' 0-bootstrap/single-cluster/1-infra/kustomization.yaml
    sed -i.bak '/namespace-baas.yaml/s/^#//g' 0-bootstrap/single-cluster/1-infra/kustomization.yaml
    sed -i.bak '/oadp-operator.yaml/s/^#//g' 0-bootstrap/single-cluster/2-services/kustomization.yaml
    sed -i.bak '/oadp-instance.yaml/s/^#//g' 0-bootstrap/single-cluster/2-services/kustomization.yaml
    sed -i.bak '/baas-operator.yaml/s/^#//g' 0-bootstrap/single-cluster/2-services/kustomization.yaml
    sed -i.bak '/baas-instance.yaml/s/^#//g' 0-bootstrap/single-cluster/2-services/kustomization.yaml
    rm 0-bootstrap/single-cluster/2-services/kustomization.yaml.bak
    rm 0-bootstrap/single-cluster/1-infra/kustomization.yaml.bak
    git add .
    git commit -m "Adding Backup as a Service instance"
    git push origin
    popd

    echo "BAAS instance configured"
}

wait_for_spectrum_ready () {
    set +e
    echo -n "Waiting for SPP server to run "
    sppok=$(oc get pod -n spp --no-headers | grep sppvirgo | grep Running | wc -l)
    until [ $sppok -eq 1 ]; do
      sleep 30
      sppok=$(oc get pod -n spp --no-headers | grep sppvirgo | grep Running | wc -l)
      echo -n "."
    done
    echo "Running"

    echo -n "Waiting for SPP server to be ready"
    sppok=$(oc get pod -n spp --no-headers | grep sppvirgo | grep '1/1' | wc -l)
      until [ $sppok -eq 1 ]; do
      sleep 30
      sppok=$(oc get pod -n spp --no-headers | grep sppvirgo | grep '1/1' | wc -l)
      echo -n "."
    done
    echo "Ready"
    set -e
    echo " ----------------------------------------------- "
    echo "You can now login to Spectrum Protect Plus UI at https://ibmspp.apps.${CLUSTER_DOMAIN}"
    echo "Userid: ${ADMINUSER} and password: ${ADMINPW}"
    echo " ----------------------------------------------- "

}

wait_for_baas_ready () {
    set +e
    echo -n "Waiting for BaaS Transaction Manager is ready"
    sppok=$(oc get pod -n baas --no-headers | grep "baas-transaction-manager" | grep -v '3/3' | wc -l)
    until [ $sppok -eq 0 ]; do
      sleep 30
      sppok=$(oc get pod -n baas --no-headers | grep "baas-transaction-manager" | grep -v '3/3' | wc -l)
      echo -n "."
    done
    echo "BaaS is running"
    set -e
}

[ "$1" = "-h" -o "$1" = "--help"  -o "$1" = "-?" ] && display_help 

check_prereqs

enable_prereq_applications

collect_info

[[ ${DEPLOYSPP} == "true" ]] && build_spp_instance

[[ ${DEPLOYBAAS} == "true" ]] && build_baas

[[ ${DEPLOYSPP} == "true" ]] && wait_for_spectrum_ready

[[ ${DEPLOYBAAS == "true" ]] && wait_for_baas_ready