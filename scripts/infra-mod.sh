#!/bin/bash

## Script to request infrastructure and storage nodes
## Script to install OCS
## Based on Cloud-Native-Toolkit gitops production reference

## Requirements:
##
## - A working OpenShift 4.7 cluster on aws/azure/vsphere
## - The oc command client
## - Run this script under the multi-tenancy-gitops git structure
##

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

set +e
oc version --client | grep '4.7\|4.8'
OC_VERSION_CHECK=$?
set -e
if [[ ${OC_VERSION_CHECK} -ne 0 ]]; then
    echo "Please use oc client version 4.7 or 4.8 download from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/ "
fi

# Check whether in GIT multi-tenancy-gitops

pushd ${SCRIPTDIR}/..

if [[ -d "0-bootstrap" ]]; then
    echo "Finding 0-bootstrap directory."
else
    echo "Cannot ensure that you are in multi-tenancy-gitops or its copy"
    exit 100
fi

popd

# Check whether OpenShift is connected

set +e
if oc cluster-info>/dev/null 2>&1; then
    echo "Cluster is connected"
else
    echo "Not connected to a cluster"
    exit 200
fi
set -e

# uncomment the kustomize.yaml - which one?

echo "Applying Infrastructure updates"

pushd ${SCRIPTDIR}/../0-bootstrap/single-cluster/1-infra

ocpversion=$(oc get clusterversion version | grep -v NAME | awk '{print $2}')
a=( ${ocpversion//./ } )
majorVer="${a[0]}.${a[1]}"
installconfig=$(oc get configmap cluster-config-v1 -n kube-system -o jsonpath='{.data.install-config}')
if echo $installconfig|grep 'api.openshift.com/managed';then
    managed1=$(echo "${installconfig}" | grep "api.openshift.com\/managed" | cut -d":" -f2  )
    managed=${managed1:-"false"}
else
    managed="false"
fi

infraID=$(oc get -o jsonpath='{.status.infrastructureName}' infrastructure cluster)
platform=$(echo "${installconfig}" | grep -A1 "^platform:" | grep -v "platform:" | cut -d":" -f1 | xargs)
shopt -s extglob
if [[ $platform == @(aws|azure|vsphere) ]]; then
    echo "Platform ${platform} is valid"
else
    echo "Supported platform is not found"
    exit 300
fi

if [[ "${platform}" == "vsphere" ]]; then
    vsconfig=$(echo "${installconfig}" | grep -A12 "^platform:" | grep "^    " | grep -v "  vsphere:")
    VS_NETWORK=$(echo "${vsconfig}"  | grep "network " | cut -d":" -f2 | xargs)
    VS_DATACENTER=$(echo "${vsconfig}" | grep "datacenter" | cut -d":" -f2 | xargs)
    VS_DATASTORE=$(echo "${vsconfig}" | grep "defaultDatastore" | cut -d":" -f2 | xargs)
    VS_CLUSTER=$(echo "${vsconfig}" | grep "cluster" | cut -d":" -f2 | xargs)
    VS_SERVER=$(echo "${vsconfig}" | grep "vCenter" | cut -d":" -f2 | xargs)
else
    region=$(echo "${installconfig}" | grep "region:" | cut -d":" -f2  | xargs)
    if [[ "$platform" == "aws"  ]]; then
        image=$(curl -k -s https://raw.githubusercontent.com/openshift/installer/release-${majorVer}/data/data/rhcos.json | grep -A1 "${region}" | grep hvm | cut -d'"' -f4)
        elif [[ "$platform" == "azure"  ]]; then
        image=$(curl -k -s https://raw.githubusercontent.com/openshift/installer/release-${majorVer}/data/data/rhcos.json | grep -A3 "azure" | grep '"image"' | cut -d'"' -f4)
        elif [[ "$platform" == "gcp"  ]]; then
        image=$(curl -k -s https://raw.githubusercontent.com/openshift/installer/release-${majorVer}/data/data/rhcos.json | grep -A3 "gcp" | grep '"image"' | cut -d'"' -f4)
    fi
fi
# platform=$(oc get -o jsonpath='{.status.platform}' infrastructure cluster | tr [:upper:] [:lower:])

sed -i.bak '/machinesets.yaml/s/^#//g' kustomization.yaml
rm kustomization.yaml.bak

# edit argocd/machinesets.yaml
sed -i'.bak' -e "s#\${PLATFORM}#${platform}#" argocd/machinesets.yaml
sed -i'.bak' -e "s#\${MANAGED}#${managed}#" argocd/machinesets.yaml
sed -i'.bak' -e "s#\${INFRASTRUCTURE_ID}#${infraID}#" argocd/machinesets.yaml
if [[ "${platform}" == "vsphere" ]]; then
    sed -i'.bak' -e "s#\${VS_NETWORK}#${VS_NETWORK}#" argocd/machinesets.yaml
    sed -i'.bak' -e "s#\${VS_DATACENTER}#${VS_DATACENTER}#" argocd/machinesets.yaml
    sed -i'.bak' -e "s#\${VS_DATASTORE}#${VS_DATASTORE}#" argocd/machinesets.yaml
    sed -i'.bak' -e "s#\${VS_CLUSTER}#${VS_CLUSTER}#" argocd/machinesets.yaml
    sed -i'.bak' -e "s#\${VS_SERVER}#${VS_SERVER}#" argocd/machinesets.yaml
else
    sed -i'.bak' -e "s#\${REGION}#${region}#" argocd/machinesets.yaml
    sed -i'.bak' -e "s#\${IMAGE_NAME}#${image}#" argocd/machinesets.yaml
fi

rm argocd/machinesets.yaml.bak


sed -i.bak '/infraconfig.yaml/s/^#//g' kustomization.yaml
rm kustomization.yaml.bak

# edit argocd/infraconfig.yaml
sed -i'.bak' -e "s#\${PLATFORM}#${platform}#" argocd/infraconfig.yaml
sed -i'.bak' -e "s#\${MANAGED}#${managed}#" argocd/infraconfig.yaml
rm argocd/infraconfig.yaml.bak

sed -i.bak '/namespace-openshift-storage.yaml/s/^#//g' kustomization.yaml
sed -i.bak '/storage.yaml/s/^#//g' kustomization.yaml
rm kustomization.yaml.bak
# edit argocd/storage.yaml
newChannel="stable-${majorVer}"
defsc=$(oc get sc | grep default | awk '{print $1}')
if [[ "$platform" == "aws" ]]; then
    storageClass=${defsc:-"gp2"}
    elif [[ "$platform" == "azure" ]]; then
    storageClass=${defsc:-"managed-premium"}
    elif [[ "$platform" == "gcp" ]]; then
    storageClass=${defsc:-"standard"}
fi

sed -i.bak "s#\${CHANNEL}#${newChannel}#" argocd/storage.yaml
sed -i.bak "s#\${STORCLASS}#${storageClass}#" argocd/storage.yaml
rm argocd/storage.yaml.bak


popd

pushd "${SCRIPTDIR}/.."

${SCRIPTDIR}/sync-manifests.sh

git add .

git commit -m "Editing infrastructure definitions"

git push origin

popd
