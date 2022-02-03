#!/usr/bin/env bash

set -euo pipefail

TOOLKIT_NAMESPACE=${TOOLKIT_NAMESPACE:-tools}
GIT_CRED_USERNAME=${GIT_CRED_USERNAME:-toolkit}
GIT_CRED_PASSWORD=${GIT_CRED_PASSWORD:-toolkit}

OPERATOR_NAME="gitea-operator"
OPERATOR_NAMESPACE="openshift-operators"
DEPLOYMENT="${OPERATOR_NAME}-controller-manager"
INSTANCE_NAME=${INSTANCE_NAME:-gitea}

if [[ $(oc get subscription ${OPERATOR_NAME} -n ${OPERATOR_NAMESPACE} 2> /dev/null) ]]; then
  echo "Gitea operator already installed"
else
  echo "Install gitea operator"
  helm template ${OPERATOR_NAME} gitea-operator --repo "https://lsteck.github.io/toolkit-charts" | kubectl apply --validate=false -f -

  # Wait for Deployment
  count=0
  until kubectl get deployment "${DEPLOYMENT}" -n "${OPERATOR_NAMESPACE}" 1> /dev/null 2> /dev/null ;
  do
    if [[ ${count} -eq 50 ]]; then
      echo "Timed out waiting for deployment/${DEPLOYMENT} in ${OPERATOR_NAMESPACE} to start"
      kubectl get deployment "${DEPLOYMENT}" -n "${OPERATOR_NAMESPACE}" 
      exit 1
    else
      count=$((count + 1))
    fi

    echo "${count} Waiting for deployment/${DEPLOYMENT} in ${OPERATOR_NAMESPACE} to start"
    sleep 10
  done

  if kubectl get deployment "${DEPLOYMENT}" -n "${OPERATOR_NAMESPACE}" 1> /dev/null 2> /dev/null; then
    kubectl rollout status deployment "${DEPLOYMENT}" -n "${OPERATOR_NAMESPACE}"
  fi

  # Wait for Pods
  count=0
  while kubectl get pods -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' -n "${OPERATOR_NAMESPACE}" | grep -q Pending; do
    if [[ ${count} -eq 50 ]]; then
      echo "Timed out waiting for pods in ${OPERATOR_NAMESPACE} to start"
      kubectl get pods -n "${OPERATOR_NAMESPACE}"
      exit 1
    else
      count=$((count + 1))
    fi

    echo "${count} Waiting for all pods in ${NAMESPACE} to start"
    sleep 10
  done
fi

# Create toolkit namespace if it doesn't exist
oc new-project ${TOOLKIT_NAMESPACE} || true

status=$(oc get pods -n ${TOOLKIT_NAMESPACE} -l app=${INSTANCE_NAME} 2> /dev/null)
if [[ "$status" =~ "Running" ]]; then
  echo "Gitea server already installed"
else
  echo "Install Gitea server"
  TMP_DIR=$(mktemp -d)
  pushd "${TMP_DIR}"
cat > "values.yaml" <<EOF
global: {}
giteaInstance:
  name: ${INSTANCE_NAME}
  namespace: ${TOOLKIT_NAMESPACE}
  giteaAdminUser: ${GIT_CRED_USERNAME}
  giteaAdminPassword: ${GIT_CRED_PASSWORD}
  giteaAdminEmail: ${GIT_CRED_USERNAME}@cloudnativetoolkit.dev
EOF
  helm template ${INSTANCE_NAME} gitea-instance --repo "https://charts.cloudnativetoolkit.dev" --values "values.yaml" | kubectl apply --validate=false -f -

  popd

  PODS="name=postgresql-${INSTANCE_NAME},app=${INSTANCE_NAME}"
  ROUTES="${INSTANCE_NAME}"
  IFS=","

  for POD in ${PODS}; do

    count=0
    until [ $(kubectl get pods -l "${POD}" -n "${TOOLKIT_NAMESPACE}" 2> /dev/null | wc -l) -gt 0 ];
    do
      if [[ ${count} -eq 50 ]]; then
        echo "Timed out waiting for pod -l ${POD} in ${TOOLKIT_NAMESPACE} to be created"
        kubectl get pods -l "${POD}" -n "${TOOLKIT_NAMESPACE}" 
        exit 1
      else
        count=$((count + 1))
      fi

      echo "${count} Waiting for pod -l ${POD} in ${TOOLKIT_NAMESPACE} to be created"
      sleep 10
    done

    count=0
    until kubectl get pods -l "${POD}" -n "${TOOLKIT_NAMESPACE}" -o jsonpath="{.items[0]['status.phase']}" | grep -q Running;
    do
      if [[ ${count} -eq 50 ]]; then
        echo "Timed out waiting for pod -l ${POD} in ${TOOLKIT_NAMESPACE} to be running"
        kubectl get pods -l "${POD}"  -n "${TOOLKIT_NAMESPACE}" 
        exit 1
      else
        count=$((count + 1))
      fi

      echo "${count} Waiting for pod -l ${POD} in ${TOOLKIT_NAMESPACE} to be running"
      sleep 10
    done

  done


  for ROUTE in ${ROUTES}; do
    count=0
    until kubectl get route "${ROUTE}" -n "${TOOLKIT_NAMESPACE}" 1> /dev/null 2> /dev/null ;
    do
      if [[ ${count} -eq 50 ]]; then
        echo "Timed out waiting for route/${ROUTE} in ${TOOLKIT_NAMESPACE} to be created"
        kubectl get route "${ROUTE}" -n "${TOOLKIT_NAMESPACE}" 
        exit 1
      else
        count=$((count + 1))
      fi

      echo "${count} Waiting for route/${ROUTE} in ${TOOLKIT_NAMESPACE} to be created"
      sleep 10
    done
  done


# else Install Gitea server
fi 


echo "Checking for toolkit admin account"
# Create toolkit admin user if needed.
ADMIN_USER=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.username|base64decode}}")
if [[ ${GIT_CRED_USERNAME} == ${ADMIN_USER} ]]; then
  echo "toolkit admin account exists"
else
  echo "Creating toolkit admin account"
  ADMIN_PASSWORD=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.password|base64decode}}")
  GIT_HOST=$(oc get route ${INSTANCE_NAME} -n ${TOOLKIT_NAMESPACE} -o jsonpath='{.spec.host}')
  # Add toolkit admin user
  curl -s -X POST -H "Content-Type: application/json" -d "{ \"username\": \"${GIT_CRED_USERNAME}\",   \"password\": \"${GIT_CRED_PASSWORD}\",   \"email\": \"${GIT_CRED_USERNAME}@cloudnativetoolkit.dev\", \"must_change_password\": false }" "https://${ADMIN_USER}:${ADMIN_PASSWORD}@${GIT_HOST}/api/v1/admin/users" > /dev/null
  # Make toolkit admin user an admin
  curl -s -X PATCH -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"login_name\": \"${GIT_CRED_USERNAME}\", \"email\": \"${GIT_CRED_USERNAME}@cloudnativetoolkit.dev\", \"active\": true, \"admin\": true, \"allow_create_organization\": true, \"allow_git_hook\": true, \"allow_import_local\": true, \"visibility\": \"public\"}" "https://${ADMIN_USER}:${ADMIN_PASSWORD}@${GIT_HOST}/api/v1/admin/users/${GIT_CRED_USERNAME}" > /dev/null

fi





