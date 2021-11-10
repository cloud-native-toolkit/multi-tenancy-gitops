#!/usr/bin/env bash

set -eo pipefail

# Get the script directory
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

if [ -z ${NAME} ]; then 
  echo "Please provide a name for your IBM API Connect Gateway and Analytics cluster"
  exit 1
fi

echo "Creating a new IBM Gateway and Analytics cluster called ${NAME}"

set -u

PROFILE_PATH="${SCRIPTDIR}/../../../../0-bootstrap/others/apic-multi-cluster"

# Check there is not a cluster with that name already
pushd ${PROFILE_PATH} > /dev/null
for directory in `ls -d */`
do
  # Check that the cluster name does not exist alraedy
  if [[ "${directory}" == "${NAME}-gateway-analytics-cluster/" ]]; then
    echo "[ERROR] - The name ${NAME} you chose for you new IBM API Connect Gateway and Analytics cluster already exists. Please, choose a different name."
    exit 1
  fi
done

popd > /dev/null

# Copy the cluster folder
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

echo "Your new cluster can be found in the ${NAME}-gateway-analytics-cluster folder"
echo "The bootstrap ArgoCD application for you new cluster is bootstrap-${NAME}-gateway-analytics-cluster.yaml"