#!/usr/bin/env bash

set -eo pipefail

#USE_GITEA=${USE_GITEA:-false}

#if [[ "${USE_GITEA}" == "true" ]]; then
#  exec $(dirname "${BASH_SOURCE}")/bootstrap-gitea.sh
#fi

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}


GIT_ORG=${GIT_ORG:-gitops-org}
mkdir -p "${OUTPUT_DIR}"

CP_EXAMPLES=${CP_EXAMPLES:-false}
ACE_SCENARIO=${ACE_SCENARIO:-false}
ACE_BOM_PATH=${ACE_BOM_PATH:-scripts/bom/ace}
CP_DEFAULT_TARGET_NAMESPACE=${CP_DEFAULT_TARGET_NAMESPACE:-tools}

GITOPS_PROFILE=${GITOPS_PROFILE:-0-bootstrap/single-cluster}

GIT_BRANCH=${GIT_BRANCH:-master}
GIT_PROTOCOL=${GIT_PROTOCOL:-https}
GIT_HOST=${GIT_HOST:-github.com}
GIT_BASEURL=${GIT_BASEURL:-${GIT_PROTOCOL}://${GIT_HOST}}
GIT_GITOPS=${GIT_GITOPS:-multi-tenancy-gitops.git}
GIT_GITOPS_BRANCH=${GIT_GITOPS_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_INFRA=${GIT_GITOPS_INFRA:-multi-tenancy-gitops-infra.git}
GIT_GITOPS_INFRA_BRANCH=${GIT_GITOPS_INFRA_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_SERVICES=${GIT_GITOPS_SERVICES:-multi-tenancy-gitops-services.git}
GIT_GITOPS_SERVICES_BRANCH=${GIT_GITOPS_SERVICES_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_APPLICATIONS=${GIT_GITOPS_APPLICATIONS:-multi-tenancy-gitops-apps.git}
GIT_GITOPS_APPLICATIONS_BRANCH=${GIT_GITOPS_APPLICATIONS_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_NAMESPACE=${GIT_GITOPS_NAMESPACE:-openshift-gitops}


IBM_CP_IMAGE_REGISTRY=${IBM_CP_IMAGE_REGISTRY:-cp.icr.io}
IBM_CP_IMAGE_REGISTRY_USER=${IBM_CP_IMAGE_REGISTRY_USER:-cp}

install_gitea () {
  echo "install gitea"
  TOOLKIT_NAMESPACE=${TOOLKIT_NAMESPACE:-tools}
  GIT_CRED_USERNAME=${GIT_CRED_USERNAME:-toolkit}
  GIT_CRED_PASSWORD=${GIT_CRED_PASSWORD:-toolkit}

  OPERATOR_NAME="gitea-operator"
  OPERATOR_NAMESPACE="openshift-operators"
  DEPLOYMENT="${OPERATOR_NAME}-controller-manager"
  INSTANCE_NAME=${INSTANCE_NAME:-gitea}

  echo "Install gitea operator"
  helm template ${OPERATOR_NAME} gitea-operator --repo "https://lsteck.github.io/toolkit-charts" | kubectl apply --validate=false -f -

  # Wait for Deployment
  count=0
  until kubectl get deployment "${DEPLOYMENT}" -n "${OPERATOR_NAMESPACE}" 1> /dev/null 2> /dev/null ;
  do
    if [[ ${count} -eq 50 ]]; then
      echo "Timed out waiting for deployment/${DEPLOYMENT} in ${OPERATOR_NAMESPACE} to start"
      kubectl get deployment "${DEPLOYMENT}" -n "${OPERATOR_NAMESPACE}" 
      echo "deployment/${DEPLOYMENT} in ${OPERATOR_NAMESPACE} is started"
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
  local seconds=1200s
  echo "INFO Wait for gitea operator pods to be ready."
  while true; do
    if [[ $(oc get pod -l control-plane=controller-manager -n "${OPERATOR_NAMESPACE}" --insecure-skip-tls-verify=true | wc -l) -gt 0 ]]; then
      oc wait pod -l control-plane=controller-manager -n "${OPERATOR_NAMESPACE}" --for=condition=Ready --timeout=${seconds} --insecure-skip-tls-verify=true ||
        echo "WARNING: Some pods for gitea operator are not ready after ${seconds}."
      break
    fi
  done
  echo "INFO: State of all pods."
  oc get pod -n "${OPERATOR_NAMESPACE}" --insecure-skip-tls-verify=true

  # Create toolkit namespace if it doesn't exist
  oc new-project ${TOOLKIT_NAMESPACE} --insecure-skip-tls-verify=true || true

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

    local seconds=1200s
    for label in name=postgresql-${INSTANCE_NAME} app=${INSTANCE_NAME}; do
      echo "INFO Wait for ${label} pods to be ready."
      while true; do
        if [[ $(oc get pod -l ${label} -n "${TOOLKIT_NAMESPACE}" --insecure-skip-tls-verify=true | wc -l) -gt 0 ]]; then
          oc wait pod -l ${label} -n "${TOOLKIT_NAMESPACE}" --for=condition=Ready --timeout=${seconds} --insecure-skip-tls-verify=true ||
            echo "WARNING: Some pods for ${label} are not ready after ${seconds}."
          break
        fi
      done
    done

    echo "checking routes"
    ROUTES="${INSTANCE_NAME}"
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


  #echo "Checking for toolkit admin account"
  # Create toolkit admin user if needed.
  #ADMIN_USER=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.username|base64decode}}")
  #if [[ ${GIT_CRED_USERNAME} == ${ADMIN_USER} ]]; then
  #  echo "toolkit admin account exists"
  #else
  #  echo "Creating toolkit admin account"
  #  ADMIN_PASSWORD=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.password|base64decode}}")
  #  GIT_HOST=$(oc get route ${INSTANCE_NAME} -n ${TOOLKIT_NAMESPACE} -o jsonpath='{.spec.host}')
  #  # Add toolkit admin user
  #  curl -s -X POST -H "Content-Type: application/json" -d "{ \"username\": \"${GIT_CRED_USERNAME}\",   \"password\": \"${GIT_CRED_PASSWORD}\",   \"email\": \"${GIT_CRED_USERNAME}@cloudnativetoolkit.dev\", \"must_change_password\": false }" "https://${ADMIN_USER}:${ADMIN_PASSWORD}@${GIT_HOST}/api/v1/admin/users" > /dev/null
  #  # Make toolkit admin user an admin
  #  curl -s -X PATCH -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"login_name\": \"${GIT_CRED_USERNAME}\", \"email\": \"${GIT_CRED_USERNAME}@cloudnativetoolkit.dev\", \"active\": true, \"admin\": true, \"allow_create_organization\": true, \"allow_git_hook\": true, \"allow_import_local\": true, \"visibility\": \"public\"}" "https://${ADMIN_USER}:${ADMIN_PASSWORD}@${GIT_HOST}/api/v1/admin/users/${GIT_CRED_USERNAME}" > /dev/null
  #fi
}

clone_repos () {
    echo "clone repos"
    echo "Github user/org is ${GIT_ORG}"

    TOOLKIT_NAMESPACE=${TOOLKIT_NAMESPACE:-tools}
    INSTANCE_NAME=${INSTANCE_NAME:-gitea}
    ADMIN_USER=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.username|base64decode}}")
    ADMIN_PASSWORD=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.password|base64decode}}")
    GITEA_BRANCH=${GITEA_BRANCH:-master}
    GITEA_PROTOCOL=${GITEA_PROTOCOL:-https}
    GITEA_HOST=$(oc get route ${INSTANCE_NAME} -n ${TOOLKIT_NAMESPACE} -o jsonpath='{.spec.host}')
    GITEA_BASEURL=${GITEA_BASEURL:-${GITEA_PROTOCOL}://${ADMIN_USER}:${ADMIN_PASSWORD}@${GITEA_HOST}}
    GIT_GITOPS=${GIT_GITOPS:-multi-tenancy-gitops.git}
    GITEA_GITOPS_BRANCH=${GITEA_GITOPS_BRANCH:-${GITEA_BRANCH}}
    GITEA_GITOPS_INFRA_BRANCH=${GITEA_GITOPS_INFRA_BRANCH:-${GITEA_BRANCH}}
    GITEA_GITOPS_SERVICES_BRANCH=${GITEA_GITOPS_SERVICES_BRANCH:-${GITEA_BRANCH}}
    GITEA_GITOPS_APPLICATIONS_BRANCH=${GITEA_GITOPS_APPLICATIONS_BRANCH:-${GITEA_BRANCH}}

    GITOPS_REPOS="${GIT_BASEURL}/cloud-native-toolkit/multi-tenancy-gitops,multi-tenancy-gitops,gitops-0-bootstrap \
              ${GIT_BASEURL}/cloud-native-toolkit/multi-tenancy-gitops-infra,multi-tenancy-gitops-infra,gitops-1-infra \
              ${GIT_BASEURL}/cloud-native-toolkit/multi-tenancy-gitops-services,multi-tenancy-gitops-services,gitops-2-services"
              

    #if [[ "${CP_EXAMPLES}" == "true" ]]; then
    #    GITOPS_REPOS=${GITOPS_REPOS}" ${GIT_BASEURL}/cloud-native-toolkit/multi-tenancy-gitops-apps,multi-tenancy-gitops-apps,gitops-3-apps"

    #    if [[ "${ACE_SCENARIO}" == "true" ]]; then
    #      GITOPS_REPOS=${GITOPS_REPOS}" ${GIT_BASEURL}/cloud-native-toolkit-demos/ace-customer-details,ace-customer-details,src-ace-app-customer-details"
    #    fi
    #fi

    # create org
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null "${GITEA_BASEURL}/api/v1/orgs/${GIT_ORG}")
    if [[ "${response}" == "200" ]]; then
      echo "org already exists ${GIT_ORG}"
          # CAN NOT delete org with repos and recreating doesn't complain so don't check]
    else
      echo "Creating org for ${GITEA_BASEURL}/api/v1/orgs ${GIT_ORG}"
      curl -X POST -H "Content-Type: application/json" -d "{ \"username\": \"${GIT_ORG}\", \"visibility\": \"public\", \"url\": \"\"  }" "${GITEA_BASEURL}/api/v1/orgs"
    fi

    # create repos
    for i in ${GITOPS_REPOS}; do
      IFS=","
      set $i
      echo "snapshot git repo $1 into $3"
      response=$(curl --write-out '%{http_code}' --silent --output /dev/null "${GITEA_BASEURL}/api/v1/repos/${GIT_ORG}/$2")
      if [[ "${response}" == "200" ]]; then
        echo "repo already exists ${GITEA_BASEURL}/${GIT_ORG}/$2.git"
        continue
      fi

      echo "Creating repo for ${GITEA_BASEURL}/${GIT_ORG}/$2.git"
      curl -X POST -H "Content-Type: application/json" -d "{ \"name\": \"${2}\", \"default_branch\": \"${GITEA_BRANCH}\" }" "${GITEA_BASEURL}/api/v1/orgs/${GIT_ORG}/repos"

      git clone --depth 1 $1 $3
      cd $3
      rm -rf .git
      git init
      git checkout -b ${GITEA_BRANCH}
      git config --local user.email "toolkit@cloudnativetoolkit.dev"
      git config --local user.name "IBM Cloud Native Toolkit"
      git add .
      git commit -m "initial commit"
      git tag 1.0.0
      git remote add downstream ${GITEA_BASEURL}/${GIT_ORG}/$2.git
      test -e 0-bootstrap/others && rm -r 0-bootstrap/others
      git push downstream ${GITEA_BRANCH}
      git push --tags downstream

      cd ..
      unset IFS
    done



}

check_infra () {
  echo "Applying Infrastructure updates"
  echo $PWD

  pushd ./gitops-0-bootstrap/0-bootstrap/single-cluster/1-infra
  echo $PWD

  #not ROSA or ROKS
  echo "set infra variables"
  managed="false"
  echo $managed

  infraID=$(oc get -o jsonpath='{.status.infrastructureName}' infrastructure cluster)
  echo $infraID
  installconfig=$(oc get configmap cluster-config-v1 -n kube-system -o jsonpath='{.data.install-config}')
  echo $installconfig
  platform=$(echo "${installconfig}" | grep -A1 "^platform:" | grep -v "platform:" | cut -d":" -f1 | xargs)
  echo $platform

  vsconfig=$(echo "${installconfig}" | grep -A12 "^platform:" | grep "^    " | grep -v "  vsphere:")
  echo $vsconfig
  VS_NETWORK=$(echo "${vsconfig}"  | grep "network" | cut -d":" -f2 | xargs)
  echo $VS_NETWORK
  VS_DATACENTER=$(echo "${vsconfig}" | grep "datacenter" | cut -d":" -f2 | xargs)
  echo $VS_DATACENTER
  VS_DATASTORE=$(echo "${vsconfig}" | grep "defaultDatastore" | cut -d":" -f2 | xargs)
  echo $VS_DATASTORE
  VS_CLUSTER=$(echo "${vsconfig}" | grep "cluster" | cut -d":" -f2 | xargs)
  echo $VS_CLUSTER
  VS_SERVER=$(echo "${vsconfig}" | grep "vCenter" | cut -d":" -f2 | xargs)
  echo $VS_SERVER

  echo "editing machineset files"

  sed -i.bak '/machinesets.yaml/s/^#//g' kustomization.yaml
  rm kustomization.yaml.bak

  sed -i'.bak' -e "s#\${PLATFORM}#${platform}#" argocd/machinesets.yaml
  sed -i'.bak' -e "s#\${MANAGED}#${managed}#" argocd/machinesets.yaml
  sed -i'.bak' -e "s#\${INFRASTRUCTURE_ID}#${infraID}#" argocd/machinesets.yaml

  sed -i'.bak' -e "s#\${VS_NETWORK}#${VS_NETWORK}#" argocd/machinesets.yaml
  sed -i'.bak' -e "s#\${VS_DATACENTER}#${VS_DATACENTER}#" argocd/machinesets.yaml
  sed -i'.bak' -e "s#\${VS_DATASTORE}#${VS_DATASTORE}#" argocd/machinesets.yaml
  sed -i'.bak' -e "s#\${VS_CLUSTER}#${VS_CLUSTER}#" argocd/machinesets.yaml
  sed -i'.bak' -e "s#\${VS_SERVER}#${VS_SERVER}#" argocd/machinesets.yaml

  rm argocd/machinesets.yaml.bak

  echo "editing infra files"

  sed -i.bak '/infraconfig.yaml/s/^#//g' kustomization.yaml
  rm kustomization.yaml.bak

  sed -i'.bak' -e "s#\${PLATFORM}#${platform}#" argocd/infraconfig.yaml
  sed -i'.bak' -e "s#\${MANAGED}#${managed}#" argocd/infraconfig.yaml
  rm argocd/infraconfig.yaml.bak

  echo "done editing files"
  popd
  echo $PWD

  echo "sync manifests"
  pushd ./gitops-0-bootstrap
  echo $PWD

  for LAYER in 1-infra 2-services 3-apps
  do

      for CLUSTER in 1-shared-cluster/cluster-1-cicd-dev-stage-prod 1-shared-cluster/cluster-n-prod 2-isolated-cluster/cluster-1-cicd-dev-stage 2-isolated-cluster/cluster-n-prod 3-multi-cluster/cluster-1-cicd 3-multi-cluster/cluster-2-dev 3-multi-cluster/cluster-3-stage 3-multi-cluster/cluster-n-prod
      do
          test -e 0-bootstrap/others/${CLUSTER}/${LAYER}/argocd && {
              rm -r 0-bootstrap/others/${CLUSTER}/${LAYER}/argocd
          }
          test -e 0-bootstrap/single-cluster && test -e 0-bootstrap/others && {
              cp -a 0-bootstrap/single-cluster/${LAYER}/{argocd,${LAYER}.yaml,kustomization.yaml} 0-bootstrap/others/${CLUSTER}/${LAYER}/
          }
      done

  done
  popd
  echo $PWD

  echo "done with Applying Infrastructre Updates"


}

install_pipelines () {
  echo "Installing OpenShift Pipelines Operator"
  oc apply -n openshift-operators -f https://raw.githubusercontent.com/cloud-native-toolkit/multi-tenancy-gitops-services/master/operators/openshift-pipelines/operator.yaml
}

install_argocd () {
    echo "Installing OpenShift GitOps Operator for OpenShift"
    pushd ${OUTPUT_DIR}
    oc create ns ${GIT_GITOPS_NAMESPACE} || true
    oc apply -f gitops-0-bootstrap/setup/ocp4x/
    while ! oc wait crd applications.argoproj.io --timeout=-1s --for=condition=Established  2>/dev/null; do sleep 30; done
    sleep 60
    while ! oc wait pod --timeout=30s --for=condition=Ready --all -n ${GIT_GITOPS_NAMESPACE} > /dev/null; do sleep 30; done
    popd
}


create_custom_argocd_instance () {
    echo "Create a custom ArgoCD instance with custom checks"
    pushd ${OUTPUT_DIR}

    oc apply -f gitops-0-bootstrap/setup/ocp4x/argocd-instance/ -n ${GIT_GITOPS_NAMESPACE}
    while ! oc wait pod --timeout=-1s --for=condition=ContainersReady -l app.kubernetes.io/name=${GIT_GITOPS_NAMESPACE}-cntk-server -n ${GIT_GITOPS_NAMESPACE} > /dev/null; do sleep 30; done
    popd
}

patch_argocd_tls () {
    echo "Patch ArgoCD instance with TLS certificate"
    pushd ${OUTPUT_DIR}

    INGRESS_SECRET_NAME=$(oc get ingresscontroller.operator default \
    --namespace openshift-ingress-operator \
    -o jsonpath='{.spec.defaultCertificate.name}')

    if [[ -z "${INGRESS_SECRET_NAME}" ]]; then
        echo "Cluster is using a self-signed certificate."
        popd
        return 0
    fi

    oc extract secret/${INGRESS_SECRET_NAME} -n openshift-ingress
    oc create secret tls -n ${GIT_GITOPS_NAMESPACE} ${GIT_GITOPS_NAMESPACE}-cntk-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml | oc apply -f -
    oc -n ${GIT_GITOPS_NAMESPACE} patch argocd/${GIT_GITOPS_NAMESPACE}-cntk --type=merge \
    -p='{"spec":{"tls":{"ca":{"secretName":"${GIT_GITOPS_NAMESPACE}-cntk-tls"}}}}'

    rm tls.key tls.crt

    popd
}


gen_argocd_patch () {
echo "Generating argocd instance patch for resourceCustomizations"
pushd ${OUTPUT_DIR}
cat <<EOF >argocd-instance-patch.yaml
spec:
  resourceCustomizations: |
    argoproj.io/Application:
      ignoreDifferences: |
        jsonPointers:
        - /spec/source/targetRevision
        - /spec/source/repoURL
    argoproj.io/AppProject:
      ignoreDifferences: |
        jsonPointers:
        - /spec/sourceRepos
EOF
popd
}

patch_argocd () {
  echo "Applying argocd instance patch"
  pushd ${OUTPUT_DIR}
  oc patch -n ${GIT_GITOPS_NAMESPACE} argocd ${GIT_GITOPS_NAMESPACE} --type=merge --patch-file=argocd-instance-patch.yaml
  popd
}

create_argocd_git_override_configmap () {
echo "Creating argocd-git-override configmap file ${OUTPUT_DIR}/argocd-git-override-configmap.yaml"
pushd ${OUTPUT_DIR}

cat <<EOF >argocd-git-override-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-git-override
data:
  map.yaml: |-
    map:
    - upstreamRepoURL: \${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS}
      originRepoUrL: ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS}
      originBranch: ${GIT_GITOPS_BRANCH}
    - upstreamRepoURL: \${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_INFRA}
      originRepoUrL: ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_INFRA}
      originBranch: ${GIT_GITOPS_INFRA_BRANCH}
    - upstreamRepoURL: \${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_SERVICES}
      originRepoUrL: ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_SERVICES}
      originBranch: ${GIT_GITOPS_SERVICES_BRANCH}
    - upstreamRepoURL: \${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_APPLICATIONS}
      originRepoUrL: ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_APPLICATIONS}
      originBranch: ${GIT_GITOPS_APPLICATIONS_BRANCH}
    - upstreamRepoURL: https://github.com/cloud-native-toolkit-demos/multi-tenancy-gitops-apps.git
      originRepoUrL: ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_APPLICATIONS}
      originBranch: ${GIT_GITOPS_APPLICATIONS_BRANCH}
EOF

popd
}

apply_argocd_git_override_configmap () {
  echo "Applying ${OUTPUT_DIR}/argocd-git-override-configmap.yaml"
  pushd ${OUTPUT_DIR}

  oc apply -n ${GIT_GITOPS_NAMESPACE} -f argocd-git-override-configmap.yaml

  popd
}
argocd_git_override () {
  echo "Deploying argocd-git-override webhook"
  oc apply -n ${GIT_GITOPS_NAMESPACE} -f https://github.com/csantanapr/argocd-git-override/releases/download/v1.1.0/deployment.yaml
  oc apply -f https://github.com/csantanapr/argocd-git-override/releases/download/v1.1.0/webhook.yaml
  oc label ns ${GIT_GITOPS_NAMESPACE} cntk=experiment --overwrite=true
  sleep 5
  oc wait pod --timeout=-1s --for=condition=Ready --all -n ${GIT_GITOPS_NAMESPACE} > /dev/null
}

set_git_source () {
  echo "setting git source instead of git override"
  echo $PWD
  pushd ./gitops-0-bootstrap
  echo $PWD
  git remote -v

  if [[ "${GITOPS_PROFILE}" == "0-bootstrap/single-cluster" ]]; then
    test -e 0-bootstrap/others && rm -r 0-bootstrap/others
  fi

  GIT_GITOPS=${GIT_GITOPS:-multi-tenancy-gitops.git}
  GIT_GITOPS_BRANCH=${GIT_GITOPS_BRANCH:-${GIT_BRANCH}}
  GIT_GITOPS_INFRA=${GIT_GITOPS_INFRA:-multi-tenancy-gitops-infra.git}
  GIT_GITOPS_INFRA_BRANCH=${GIT_GITOPS_INFRA_BRANCH:-${GIT_BRANCH}}
  GIT_GITOPS_SERVICES=${GIT_GITOPS_SERVICES:-multi-tenancy-gitops-services.git}
  GIT_GITOPS_SERVICES_BRANCH=${GIT_GITOPS_SERVICES_BRANCH:-${GIT_BRANCH}}
  GIT_GITOPS_APPLICATIONS=${GIT_GITOPS_APPLICATIONS:-multi-tenancy-gitops-apps.git}
  GIT_GITOPS_APPLICATIONS_BRANCH=${GIT_GITOPS_APPLICATIONS_BRANCH:-${GIT_BRANCH}}
  GIT_GITOPS_NAMESPACE=${GIT_GITOPS_NAMESPACE:-openshift-gitops}
  HELM_REPOURL=${HELM_REPOURL:-https://charts.cloudnativetoolkit.dev}

  echo "Setting kustomization patches to ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS} on branch ${GIT_GITOPS_BRANCH}"
  echo "Setting kustomization patches to ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_INFRA} on branch ${GIT_GITOPS_INFRA_BRANCH}"
  echo "Setting kustomization patches to ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_SERVICES} on branch ${GIT_GITOPS_SERVICES_BRANCH}"
  echo "Setting kustomization patches to ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_APPLICATIONS} on branch ${GIT_GITOPS_APPLICATIONS_BRANCH}"

  find ./0-bootstrap -name '*.yaml' -print0 |
    while IFS= read -r -d '' File; do
      if grep -q "kind: Application\|kind: AppProject" "$File"; then
        #echo "$File"
        sed -i'.bak' -e "s#\${GITOPS_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS}#${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS}#" $File
        sed -i'.bak' -e "s#\${GIT_GITOPS_BRANCH}#${GIT_GITOPS_BRANCH}#" $File
        sed -i'.bak' -e "s#\${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_INFRA}#${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_INFRA}#" $File
        sed -i'.bak' -e "s#\${GIT_GITOPS_INFRA_BRANCH}#${GIT_GITOPS_INFRA_BRANCH}#" $File
        sed -i'.bak' -e "s#\${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_SERVICES}#${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_SERVICES}#" $File
        sed -i'.bak' -e "s#\${GIT_GITOPS_SERVICES_BRANCH}#${GIT_GITOPS_SERVICES_BRANCH}#" $File
        sed -i'.bak' -e "s#\${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_APPLICATIONS}#${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_APPLICATIONS}#" $File
        sed -i'.bak' -e "s#\${GIT_GITOPS_APPLICATIONS_BRANCH}#${GIT_GITOPS_APPLICATIONS_BRANCH}#" $File
        sed -i'.bak' -e "s#\${GIT_GITOPS_NAMESPACE}#${GIT_GITOPS_NAMESPACE}#" $File
        sed -i'.bak' -e "s#\${HELM_REPOURL}#${HELM_REPOURL}#" $File
        rm "${File}.bak"
      fi
    done
  echo "done replacing variables in kustomization.yaml files"
  echo "git commit and push changes now"

  if [[ "${GIT_TOKEN}" == "exampletoken" ]]; then
    echo "git remote set-url origin with user pass"
    git remote add origin ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS}
  else
    echo "git remote set-url origin with token"
    git remote add origin ${GIT_PROTOCOL}://${GIT_TOKEN}@${GITEA_HOST}/${GIT_ORG}/${GIT_GITOPS}
  fi
  
  git push --set-upstream origin ${GIT_BRANCH}
  git add .
  git commit -m "Updating git source to ${GIT_ORG}"
  git push origin

  echo $PWD
  popd
  echo $PWD
}

deploy_bootstrap_argocd () {
  echo "Deploying top level bootstrap ArgoCD Application for cluster profile ${GITOPS_PROFILE}"
  oc apply -n ${GIT_GITOPS_NAMESPACE} -f gitops-0-bootstrap/${GITOPS_PROFILE}/bootstrap.yaml
}


update_pull_secret () {
  echo "update pull secret"
  # Only applicable when workers reload automatically
  if [[ -z "${IBM_ENTITLEMENT_KEY}" ]]; then
    echo "Please pass the environment variable IBM_ENTITLEMENT_KEY"
    exit 1
  fi
  WORKDIR=$(mktemp -d)
  # extract using oc get secret
  oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' >${WORKDIR}/.dockerconfigjson
  ls -l ${WORKDIR}/.dockerconfigjson

  # or extract using oc extract
  #oc extract secret/pull-secret --keys .dockerconfigjson -n openshift-config --confirm --to=-
  #oc extract secret/pull-secret --keys .dockerconfigjson -n openshift-config --confirm --to=./foo
  #ls -l ${WORKDIR}/.dockerconfigjson

  # merge a new entry into existing file
  oc registry login --registry="${IBM_CP_IMAGE_REGISTRY}" --auth-basic="${IBM_CP_IMAGE_REGISTRY_USER}:${IBM_ENTITLEMENT_KEY}" --to=${WORKDIR}/.dockerconfigjson
  #cat ${WORKDIR}/.dockerconfigjson

  # write back into cluster, but is better to save it to gitops repo :-)
  oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${WORKDIR}/.dockerconfigjson

  # TODO: Check if reboot is done automatically?

  # get back the yaml merged to save it in gitops git repo to be deploy with ArgoCD
  #oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${WORKDIR}/.dockerconfigjson  --dry-run=client -o yaml
}

set_pull_secret () {
  echo "set pull secret"

  if [[ -z "${IBM_ENTITLEMENT_KEY}" ]]; then
    echo "Please pass the environment variable IBM_ENTITLEMENT_KEY"
    exit 1
  fi
  oc new-project ${CP_DEFAULT_TARGET_NAMESPACE} || true
  oc create secret docker-registry ibm-entitlement-key -n ${CP_DEFAULT_TARGET_NAMESPACE} \
  --docker-username="${IBM_CP_IMAGE_REGISTRY_USER}" \
  --docker-password="${IBM_ENTITLEMENT_KEY}" \
  --docker-server="${IBM_CP_IMAGE_REGISTRY}" || true
}

init_sealed_secrets () {

  echo "Intializing sealed secrets with file ${SEALED_SECRET_KEY_FILE}"
  oc new-project sealed-secrets || true
  oc apply -f ${SEALED_SECRET_KEY_FILE}

}

ace_bom_bootstrap () {

  echo "Applying ACE BOM"

  pushd ${OUTPUT_DIR}/gitops-0-bootstrap/

  cp -a ${ACE_BOM_PATH}/1-infra/ ${GITOPS_PROFILE}/1-infra/
  cp -a ${ACE_BOM_PATH}/2-services/ ${GITOPS_PROFILE}/2-services/
  # Setup of apps repo
  if [[ "${CP_EXAMPLES}" == "true" ]]; then
    echo "Applying ACE BOM with Apps"
    cp -a ${ACE_BOM_PATH}/3-apps/ ${GITOPS_PROFILE}/3-apps/
  fi
  git --no-pager diff

  git add .

  git commit -m "Deploy Cloud Pak ACE"

  git push origin

  popd

}

ace_apps_bootstrap () {
  echo "ace bootstrap"
  echo "Github user/org is ${GIT_ORG}"

  if [ -z ${GIT_USER} ]; then echo "Please set GIT_USER when running script"; exit 1; fi

  if [ -z ${GIT_TOKEN} ]; then echo "Please set GIT_TOKEN when running script"; exit 1; fi

  if [ -z ${GIT_ORG} ]; then echo "Please set GIT_ORG when running script"; exit 1; fi

  pushd ${OUTPUT_DIR}

  source gitops-3-apps/scripts/ace-bootstrap.sh

  popd

}

delete_default_argocd_instance () {
    echo "Delete the default ArgoCD instance"
    oc delete gitopsservice cluster -n openshift-gitops || true
}

create_custom_argocd_instance () {
    echo "Create a custom ArgoCD instance with custom checks"

    oc apply -f gitops-0-bootstrap/setup/ocp4x/argocd-instance/ -n openshift-gitops
    while ! oc wait pod --timeout=-1s --for=condition=ContainersReady -l app.kubernetes.io/name=openshift-gitops-cntk-server -n openshift-gitops > /dev/null; do sleep 30; done
}
patch_argocd_tls () {
    echo "Patch ArgoCD instance with TLS certificate"

    INGRESS_SECRET_NAME=$(oc get ingresscontroller.operator default \
    --namespace openshift-ingress-operator \
    -o jsonpath='{.spec.defaultCertificate.name}')

    if [[ -z "${INGRESS_SECRET_NAME}" ]]; then
        echo "Cluster is using a self-signed certificate."
        return 0
    fi

    oc extract secret/${INGRESS_SECRET_NAME} -n openshift-ingress
    oc create secret tls -n openshift-gitops openshift-gitops-cntk-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml | oc apply -f -
    oc -n openshift-gitops patch argocd/openshift-gitops-cntk --type=merge \
    -p='{"spec":{"tls":{"ca":{"secretName":"openshift-gitops-cntk-tls"}}}}'

    rm tls.key tls.crt

}

print_urls_passwords () {

    echo "# Openshift Console UI: $(oc whoami --show-console)"
    echo "# "
    echo "# Openshift ArgoCD/GitOps UI: $(oc get route -n ${GIT_GITOPS_NAMESPACE} ${GIT_GITOPS_NAMESPACE}-cntk-server -o template --template='https://{{.spec.host}}')"
    echo "# "
    echo "# To get the ArgoCD/GitOps URL and admin password:"
    echo "# -----"
    echo "oc get route -n ${GIT_GITOPS_NAMESPACE} ${GIT_GITOPS_NAMESPACE}-cntk-server -o template --template='https://{{.spec.host}}'"
    echo "oc extract secrets/${GIT_GITOPS_NAMESPACE}-cntk-cluster --keys=admin.password -n ${GIT_GITOPS_NAMESPACE} --to=-"
    echo "# -----"
    echo "# The Cloud Pak console and admin password"
    echo "oc get route -n ${CP_DEFAULT_TARGET_NAMESPACE} integration-navigator-pn -o template --template='https://{{.spec.host}}'"
    echo "oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_username,admin_password --to=-"
    echo "# -----"

}

set_rwx_storage_class () {
  DEFAULT_RWX_STORAGE_CLASS=${DEFAULT_RWX_STORAGE_CLASS:-managed-nfs-storage}
  OCS_RWX_STORAGE_CLASS=${OCS_RWX_STORAGE_CLASS:-ocs-storagecluster-cephfs}
  RWX_STORAGE_CLASS=${OCS_RWX_STORAGE_CLASS}

  echo "Replacing ${DEFAULT_RWX_STORAGE_CLASS} with ${RWX_STORAGE_CLASS} storage class "
  pushd ./gitops-0-bootstrap/

  find . -name '*.yaml' -print0 |
    while IFS= read -r -d '' File; do
      if grep -q "${DEFAULT_RWX_STORAGE_CLASS}" "$File"; then
        #echo "$File"
        sed -i'.bak' -e "s#${DEFAULT_RWX_STORAGE_CLASS}#${RWX_STORAGE_CLASS}#" $File
        rm "${File}.bak"
      fi
    done

  git --no-pager diff

  git add .

  git commit -m "Change RWX storage class to ${RWX_STORAGE_CLASS}"

  git push origin

  popd
}


# master
echo "install gitops"
install_gitea

sleep 120 

clone_repos

if [[ -n "${IBM_ENTITLEMENT_KEY}" ]]; then
  update_pull_secret
  set_pull_secret
fi

if [[ -n "${SEALED_SECRET_KEY_FILE}" ]]; then
  init_sealed_secrets
fi

check_infra

#install_pipelines

install_argocd

#gen_argocd_patch

#patch_argocd

delete_default_argocd_instance

create_custom_argocd_instance

patch_argocd_tls

# Either you map the GIT source using set_git_source or using argocd_git_override - but not both

#create_argocd_git_override_configmap
#apply_argocd_git_override_configmap
#argocd_git_override

set_git_source

# Set RWX storage
set_rwx_storage_class

deploy_bootstrap_argocd

# Setup BOM
if [[ "${ACE_SCENARIO}" == "true" ]]; then
  echo "Bootstrap Cloud Pak for ACE"
  ace_bom_bootstrap
  # Setup of apps repo
  if [[ "${CP_EXAMPLES}" == "true" ]]; then
    echo "Bootstrap Cloud Pak examples for ACE"
    ace_apps_bootstrap
  fi
fi

print_urls_passwords

exit 0
