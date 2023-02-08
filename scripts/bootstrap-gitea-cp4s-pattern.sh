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


set +e
oc version --client | grep '4.7\|4.8'
OC_VERSION_CHECK=$?
set -e
if [[ ${OC_VERSION_CHECK} -ne 0 ]]; then
  echo "Please use oc client version 4.7 or 4.8 download from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/ "
fi

GIT_ORG=${GIT_ORG:-gitops-org}

if [[ -z ${OUTPUT_DIR} ]]; then
  echo "Please set the environment variable OUTPUT_DIR when running the script like:"
  echo "OUTPUT_DIR=gitops-production ./scripts/bootstrap-gitea.sh"
  echo "You can also specify the GIT ORG (defaults to gitops-org) with environment variable GIT_ORG when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap-gitea.sh"

  exit 1
fi
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


IBM_CP_IMAGE_REGISTRY=${IBM_CP_IMAGE_REGISTRY:-cp.icr.io}
IBM_CP_IMAGE_REGISTRY_USER=${IBM_CP_IMAGE_REGISTRY_USER:-cp}

install_gitea () {
    bash $(dirname "${BASH_SOURCE}")/gitea-install.sh
}

clone_repos () {
    echo "Github user/org is ${GIT_ORG}"

    TOOLKIT_NAMESPACE=${TOOLKIT_NAMESPACE:-tools}
    INSTANCE_NAME=${INSTANCE_NAME:-gitea}
    ADMIN_USER=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.username|base64decode}}")
    ADMIN_PASSWORD=$(oc get secret ${INSTANCE_NAME}-access -n ${TOOLKIT_NAMESPACE} -o go-template --template="{{.data.password|base64decode}}")
    GITEA_BRANCH=${GITEA_BRANCH:-main}
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
              

    if [[ "${CP_EXAMPLES}" == "true" ]]; then
        GITOPS_REPOS=${GITOPS_REPOS}" ${GIT_BASEURL}/cloud-native-toolkit/multi-tenancy-gitops-apps,multi-tenancy-gitops-apps,gitops-3-apps"

        if [[ "${ACE_SCENARIO}" == "true" ]]; then
          GITOPS_REPOS=${GITOPS_REPOS}" ${GIT_BASEURL}/cloud-native-toolkit-demos/ace-customer-details,ace-customer-details,src-ace-app-customer-details"
        fi
    fi

    pushd ${OUTPUT_DIR}

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
    git init -b ${GITEA_BRANCH}
    git config --local user.email "toolkit@cloudnativetoolkit.dev"
    git config --local user.name "IBM Cloud Native Toolkit"
    git add .
    git commit -m "initial commit"
    git tag 1.0.0
    git remote add downstream ${GITEA_BASEURL}/${GIT_ORG}/$2.git
    git push downstream ${GITEA_BRANCH}
    git push --tags downstream

    cd ..
    unset IFS


    done

    popd

}

check_infra () {
   if [[ "${ADD_INFRA}" == "yes" ]]; then
     pushd ${OUTPUT_DIR}/gitops-0-bootstrap
       source ./scripts/infra-mod.sh
     popd
   fi
}

install_pipelines () {
  echo "Installing OpenShift Pipelines Operator"
  oc apply -n openshift-operators -f https://raw.githubusercontent.com/cloud-native-toolkit/multi-tenancy-gitops-services/master/operators/openshift-pipelines/operator.yaml
}

install_argocd () {
    echo "Installing OpenShift GitOps Operator for OpenShift v4.7"
    pushd ${OUTPUT_DIR}
    oc apply -f gitops-0-bootstrap/setup/ocp4x/
    while ! oc wait crd applications.argoproj.io --timeout=-1s --for=condition=Established  2>/dev/null; do sleep 30; done
    sleep 60
    while ! oc wait pod --timeout=30s --for=condition=Ready -l '!job-name' -n openshift-gitops > /dev/null; do sleep 30; done
    popd
}

delete_default_argocd_instance () {
    echo "Delete the default ArgoCD instance"
    pushd ${OUTPUT_DIR}
    oc delete gitopsservice cluster -n openshift-gitops || true
    popd
}

create_custom_argocd_instance () {
    echo "Create a custom ArgoCD instance with custom checks"
    pushd ${OUTPUT_DIR}

    oc apply -f gitops-0-bootstrap/setup/ocp4x/argocd-instance/ -n openshift-gitops
    while ! oc wait pod --timeout=-1s --for=condition=ContainersReady -l app.kubernetes.io/name=openshift-gitops-cntk-server -n openshift-gitops > /dev/null; do sleep 30; done
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
        return 0
    fi

    oc extract secret/${INGRESS_SECRET_NAME} -n openshift-ingress
    oc create secret tls -n openshift-gitops openshift-gitops-cntk-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml | oc apply -f -
    oc -n openshift-gitops patch argocd/openshift-gitops-cntk --type=merge \
    -p='{"spec":{"tls":{"ca":{"secretName":"openshift-gitops-cntk-tls"}}}}'

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
  oc patch -n openshift-gitops argocd openshift-gitops --type=merge --patch-file=argocd-instance-patch.yaml
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
      originRepoUrL: ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS}
      originBranch: ${GITEA_GITOPS_BRANCH}
    - upstreamRepoURL: \${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_INFRA}
      originRepoUrL: ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_INFRA}
      originBranch: ${GITEA_GITOPS_INFRA_BRANCH}
    - upstreamRepoURL: \${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_SERVICES}
      originRepoUrL: ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_SERVICES}
      originBranch: ${GITEA_GITOPS_SERVICES_BRANCH}
    - upstreamRepoURL: \${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_APPLICATIONS}
      originRepoUrL: ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_APPLICATIONS}
      originBranch: ${GITEA_GITOPS_APPLICATIONS_BRANCH}
    - upstreamRepoURL: https://github.com/cloud-native-toolkit-demos/multi-tenancy-gitops-apps.git
      originRepoUrL: ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS_APPLICATIONS}
      originBranch: ${GITEA_GITOPS_APPLICATIONS_BRANCH}
EOF

popd
}

apply_argocd_git_override_configmap () {
  echo "Applying ${OUTPUT_DIR}/argocd-git-override-configmap.yaml"
  pushd ${OUTPUT_DIR}

  oc apply -n openshift-gitops -f argocd-git-override-configmap.yaml

  popd
}
argocd_git_override () {
  echo "Deploying argocd-git-override webhook"
  oc apply -n openshift-gitops -f https://github.com/csantanapr/argocd-git-override/releases/download/v1.1.0/deployment.yaml
  oc apply -f https://github.com/csantanapr/argocd-git-override/releases/download/v1.1.0/webhook.yaml
  oc label ns openshift-gitops cntk=experiment --overwrite=true
  sleep 5
  oc wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n openshift-gitops > /dev/null
}

set_git_source () {
  echo setting git source instead of git override
  pushd ${OUTPUT_DIR}/gitops-0-bootstrap

  if [[ "${GITOPS_PROFILE}" == "0-bootstrap/single-cluster" ]]; then
    rm -r 0-bootstrap/others
  fi

  GIT_ORG=${GIT_ORG} \
  GIT_BASEURL=${GITEA_PROTOCOL}://${GITEA_HOST} \
  GIT_GITOPS_BRANCH=${GITEA_GITOPS_BRANCH} \
  GIT_GITOPS_INFRA_BRANCH=${GITEA_GITOPS_INFRA_BRANCH} \
  GIT_GITOPS_SERVICES_BRANCH=${GITEA_GITOPS_SERVICES_BRANCH} \
  GIT_GITOPS_APPLICATIONS_BRANCH=${GITEA_GITOPS_APPLICATIONS_BRANCH} \
  ./scripts/set-git-source.sh

  git remote add origin ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS}
  git push --set-upstream origin ${GITEA_GITOPS_BRANCH}
  git add .
  git commit -m "Updating git source to ${GIT_ORG}"
  git push origin
  popd
}

set-git-cp4s-pattern () {

  echo setting git source instead of git override
  pushd ${OUTPUT_DIR}/gitops-0-bootstrap

  if [[ "${GITOPS_PROFILE}" == "0-bootstrap/single-cluster" ]]; then
    rm -r 0-bootstrap/others
  fi

  GIT_ORG=${GIT_ORG} \
  GIT_BASEURL=${GITEA_PROTOCOL}://${GITEA_HOST} \
  GIT_GITOPS_BRANCH=${GITEA_GITOPS_BRANCH} \
  GIT_GITOPS_INFRA_BRANCH=${GITEA_GITOPS_INFRA_BRANCH} \
  GIT_GITOPS_SERVICES_BRANCH=${GITEA_GITOPS_SERVICES_BRANCH} \
  GIT_GITOPS_APPLICATIONS_BRANCH=${GITEA_GITOPS_APPLICATIONS_BRANCH} \
  ./scripts/set-git-cp4s-pattern.sh

  git remote add origin ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS}
  git push --set-upstream origin ${GITEA_GITOPS_BRANCH}
  git add .
  git commit -m "Updating git source to ${GIT_ORG}"
  git push origin
  popd
}


deploy_bootstrap_argocd () {
  echo "Deploying top level bootstrap ArgoCD Application for cluster profile ${GITOPS_PROFILE}"
  pushd ${OUTPUT_DIR}
  oc apply -n openshift-gitops -f gitops-0-bootstrap/${GITOPS_PROFILE}/bootstrap.yaml
  popd
}


update_pull_secret () {
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
  echo "Github user/org is ${GIT_ORG}"

  if [ -z ${GIT_USER} ]; then echo "Please set GIT_USER when running script"; exit 1; fi

  if [ -z ${GIT_TOKEN} ]; then echo "Please set GIT_TOKEN when running script"; exit 1; fi

  if [ -z ${GIT_ORG} ]; then echo "Please set GIT_ORG when running script"; exit 1; fi

  pushd ${OUTPUT_DIR}

  source gitops-3-apps/scripts/ace-bootstrap.sh

  popd

}

print_urls_passwords () {

    echo "# Openshift Console UI: $(oc whoami --show-console)"
    echo "# "
    echo "# Openshift ArgoCD/GitOps UI: $(oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}')"
    echo "# "
    echo "# To get the ArgoCD/GitOps URL and admin password:"
    echo "# -----"
    echo "oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}'"
    echo "oc extract secrets/openshift-gitops-cntk-cluster --keys=admin.password -n openshift-gitops --to=-"
    echo "# -----"
    echo "# "
    echo "# Gitea UI: $(oc get route ${INSTANCE_NAME} -n ${TOOLKIT_NAMESPACE}${INSTANCE_NAME} -n ${TOOLKIT_NAMESPACE} -o template --template='https://{{.spec.host}}')"
    echo "# "
    echo "# To get the Gitea admin ID and admin password:"
    echo "# -----"
    echo "oc extract secrets/${INSTANCE_NAME}-access --keys=username,password -n ${TOOLKIT_NAMESPACE} --to=-"
    echo "# -----"

}

get_rwx_storage_class () {

  DEFAULT_RWX_STORAGE_CLASS=${DEFAULT_RWX_STORAGE_CLASS:-managed-nfs-storage}
  OCS_RWX_STORAGE_CLASS=${OCS_RWX_STORAGE_CLASS:-ocs-storagecluster-cephfs}

  if [[ -n "${RWX_STORAGE_CLASS}" ]]; then
    echo "RWX Storage class specified to ${RWX_STORAGE_CLASS}"
    return 0
  fi
  set +e
  oc get sc -o jsonpath='{.items[*].metadata.name}' | grep "${OCS_RWX_STORAGE_CLASS}"
  OC_SC_OCS_CHECK=$?
  set -e
  if [[ ${OC_SC_OCS_CHECK} -eq 0 ]]; then
    echo "Found OCS RWX storage class"
    RWX_STORAGE_CLASS="${OCS_RWX_STORAGE_CLASS}"
    return 0
  fi
  RWX_STORAGE_CLASS=${DEFAULT_RWX_STORAGE_CLASS}
}

set_rwx_storage_class () {

  if [[ ${RWX_STORAGE_CLASS} = ${DEFAULT_RWX_STORAGE_CLASS} ]]; then
    echo "Using default RWX storage managed-nfs-storage skipping override"
    return 0
  fi

  echo "Replacing ${DEFAULT_RWX_STORAGE_CLASS} with ${RWX_STORAGE_CLASS} storage class "
  pushd ${OUTPUT_DIR}/gitops-0-bootstrap/

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


# main

install_gitea

#give time gitea api to come up before creating org and repos
sleep 60

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

set-git-cp4s-pattern

# Set RWX storage
# get_rwx_storage_class
# set_rwx_storage_class

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
