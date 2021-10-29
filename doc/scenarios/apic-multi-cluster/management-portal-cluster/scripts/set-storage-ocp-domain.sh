#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x


if [ -z ${STORAGE} ]; then echo "Please set STORAGE to the block storage class name available in the OpenShift cluster where the IBM API Connect Management and Portal components are being installed"; exit 1; fi
if [ -z ${OCP_DOMAIN} ]; then echo "Please set OCP_DOMAIN to the OpenShift cluster domain where the IBM API Connect Management and Portal components are being installed"; exit 1; fi

set -u

echo "Setting the storage class name for the IBM API Connect Management and Portal components to ${STORAGE}"
echo "Setting the OpenShift domain for the IBM API Connect Management and Portal components to ${OCP_DOMAIN}"

MGMT_FILE="${SCRIPTDIR}/../2-services/argocd/instances/ibm-apic-management-portal-instance/instances/ibm-apic-management-instance.yaml"
PTL_FILE="${SCRIPTDIR}/../2-services/argocd/instances/ibm-apic-management-portal-instance/instances/ibm-apic-portal-instance.yaml"

sed -i'.bak' -e "s/<your-block-storage-class>/${STORAGE}/" ${MGMT_FILE}
sed -i'.bak' -e "s/<your-block-storage-class>/${STORAGE}/" ${PTL_FILE}
sed -i'.bak' -e "s/<your-openshift-domain>/${OCP_DOMAIN}/" ${MGMT_FILE}
sed -i'.bak' -e "s/<your-openshift-domain>/${OCP_DOMAIN}/" ${PTL_FILE}

rm "${MGMT_FILE}.bak"
rm "${PTL_FILE}.bak"

echo "Done"
