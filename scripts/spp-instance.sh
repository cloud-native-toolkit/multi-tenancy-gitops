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
    echo "This spp-instance.sh configures the spp-instance.yaml"
    echo "See https://github.com/cloud-native-toolkit/multi-tenancy-gitops for more information"
    echo ""
    echo "The following environment variables are required:"
    echo "IBM_ENTITLEMENT_KEY - IBM Container registry entitlement key"
    echo ""
    echo "The following environment variables are optional:"
    echo "SPPUSER             - Spectrum Protect plus user name - default to sppadmin"
    echo "SPPPW               - Spectrum Protect plus password - default to passw0rd"
    echo ""
    echo "Required CLIs: bash, helm, dig, jq, yq, git, gh, oc" 
    exit 1
}

check_prereqs() {
    echo "Checking prerequisites"
    ##############################################################################
    # Begin environment checking
    ##############################################################################
    
    error=0
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
    
    if [[ -z $IBM_ENTITLEMENT_KEY ]]; then
        echo >&2 "ERROR: Please supply IBM_ENTITLEMENT_KEY"
        error=$(( $error + 1 )) 
    fi

    sscount=$(oc get pod -n sealed-secrets | grep sealed-secret | wc -l)
    if [[ "${sscount}" -eq 0 ]]; then
        echo >&2 "ERROR: Sealed secret is not installed - please enable sealed-secret.yaml"
        error=$(( $error + 1 )) 
    fi    

    sppoper=$(oc get packagemanifest -n openshift-marketplace spp-operator --no-headers 2>/dev/null | wc -l)
    if [[ "$sppoper" -eq 0 ]]; then    
        echo >&2 "ERROR: SPP Catalog is not installed - please enable spp-catalog.yaml"
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
    
    ##############################################################################
    # End collecting cluster information
    ##############################################################################
}

build_spp_instance() {
    pushd ${SCRIPTDIR}/../0-bootstrap/single-cluster/2-services/argocd/instances
    # Editing spp-instance.yaml
    echo "Working on 0-bootstrap/single-cluster/2-services/argocd/instances/spp-instance.yaml"
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
    echo "SPP instance configured - Please Commit and Push your changes to GIT"

    popd

}


[ "$1" = "-h" -o "$1" = "--help"  -o "$1" = "-?" ] && display_help 

check_prereqs

collect_info

build_spp_instance
