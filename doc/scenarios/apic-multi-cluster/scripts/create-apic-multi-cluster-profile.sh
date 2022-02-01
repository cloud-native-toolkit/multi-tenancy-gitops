#!/usr/bin/env bash

set -eo pipefail

# Get the script directory
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

if [ -z ${NAME} ]; then 
  echo "Please provide a name for your IBM API Connect Gateway and Analytics cluster"
  exit 1
fi

echo "Creating an IBM API Connect multi-cluster profile under 0-bootstrap/others"
echo "The IBM Gateway and Analytics cluster will be called ${NAME}"

set -u

PROFILE_PATH="${SCRIPTDIR}/../../../../0-bootstrap/others/apic-multi-cluster"

# Make the apic-multi-cluster profile directory
mkdir ${PROFILE_PATH}

# Copy the management and portal cluster
cp -R ${SCRIPTDIR}/../management-portal-cluster ${PROFILE_PATH}/management-portal-cluster
# Copy the management and portal cluster bootstrap
cp ${SCRIPTDIR}/../bootstrap-management-portal-cluster.yaml ${PROFILE_PATH}/bootstrap-management-portal-cluster.yaml


# Copy the gateway and analytics cluster folder
cp -R ${SCRIPTDIR}/../gateway-analytics-cluster ${PROFILE_PATH}/${NAME}-gateway-analytics-cluster
# Copy the bootstrap file
cp ${SCRIPTDIR}/../bootstrap-gateway-analytics-cluster.yaml ${PROFILE_PATH}/bootstrap-${NAME}-gateway-analytics-cluster.yaml

# Point to the appropriate cluster folder in the bootstrap file
sed -i'.bak' -e "s/template-gateway-analytics-cluster/${NAME}-gateway-analytics-cluster/" "${PROFILE_PATH}/bootstrap-${NAME}-gateway-analytics-cluster.yaml"
rm "${PROFILE_PATH}/bootstrap-${NAME}-gateway-analytics-cluster.yaml.bak"

# Point to the appropriate cluster folder for any ArgoCD application
find ${PROFILE_PATH}/${NAME}-gateway-analytics-cluster -name '*.yaml' -print0 |
  while IFS= read -r -d '' File; do
    if grep -q "template-gateway-analytics-instance" "$File"; then
      # echo "$File"
      sed -i'.bak' -e "s/template-gateway-analytics-instance/${NAME}-gateway-analytics-instance/" $File
      rm "${File}.bak"
    fi
    if grep -q "template-gateway-analytics-cluster" "$File"; then
      # echo "$File"
      sed -i'.bak' -e "s/template-gateway-analytics-cluster/${NAME}-gateway-analytics-cluster/" $File
      rm "${File}.bak"
    fi
  done

# Updating console notification description
sed -i'.bak' -e "s/text: \"Cluster Description\"/text: \"${NAME} - IBM API Connect Gateway and Analytics cluster\"/" "${PROFILE_PATH}/${NAME}-gateway-analytics-cluster/1-infra/argocd/consolenotification.yaml"
rm "${PROFILE_PATH}/${NAME}-gateway-analytics-cluster/1-infra/argocd/consolenotification.yaml.bak"

echo "Done"
echo "You can find the new apic-multi-cluster profile under 0-bootsrap/others/apic-multi-cluster"