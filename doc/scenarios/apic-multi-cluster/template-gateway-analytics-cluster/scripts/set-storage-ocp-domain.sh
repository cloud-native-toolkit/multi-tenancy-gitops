#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x


if [ -z ${STORAGE} ]; then echo "Please set STORAGE to the block storage class name available in the OpenShift cluster where the IBM API Connect Gateway and Analytics components are being installed"; exit 1; fi
if [ -z ${OCP_DOMAIN} ]; then echo "Please set OCP_DOMAIN to the OpenShift cluster domain where the IBM API Connect Gateway and Analytics components are being installed"; exit 1; fi

set -u

echo "Setting the storage class name for the IBM API Connect Gateway and Analytics components to ${STORAGE}"
echo "Setting the OpenShift domain for the IBM API Connect Gateway and Analytics components to ${OCP_DOMAIN}"

GTW_FILE="${SCRIPTDIR}/../2-services/argocd/instances/ibm-apic-gateway-analytics-instance/instances/ibm-apic-gateway-instance.yaml"
A7S_FILE="${SCRIPTDIR}/../2-services/argocd/instances/ibm-apic-gateway-analytics-instance/instances/ibm-apic-analytics-instance.yaml"

sed -i'.bak' -e "s/<your-block-storage-class>/${STORAGE}/" ${GTW_FILE}
sed -i'.bak' -e "s/<your-block-storage-class>/${STORAGE}/" ${A7S_FILE}
sed -i'.bak' -e "s/<your-openshift-domain>/${OCP_DOMAIN}/" ${GTW_FILE}
sed -i'.bak' -e "s/<your-openshift-domain>/${OCP_DOMAIN}/" ${A7S_FILE}

rm "${GTW_FILE}.bak"
rm "${A7S_FILE}.bak"

echo "Done"
