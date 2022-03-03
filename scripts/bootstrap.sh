#!/usr/bin/env bash

set -eo pipefail

GIT_TARGET=${GIT_TARGET:-github}

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

command -v gh >/dev/null 2>&1 || { echo >&2 "The Github CLI gh but it's not installed. Download https://github.com/cli/cli "; exit 1; }

set +e
#oc version --client | grep '4.7\|4.8'
oc version --client | grep -E '4.[7-9].[0-9]|4.[1-9][0-9].[0-9]|4.[1-9][0-9][0-9].[0-9]'
OC_VERSION_CHECK=$?
set -e
if [[ ${OC_VERSION_CHECK} -ne 0 ]]; then
  echo "Please use oc client version 4.7 or 4.8 download from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/ "
fi


if [[ -z ${GIT_ORG} ]]; then
  if [[ "${GIT_TARGET}" == "gitea" ]]; then
    GIT_ORG="gitops-org"
  else
    echo "We recommend to create a new github organization for all your gitops repos"
    echo "Setup a new organization on github https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch"
    echo "Please set the environment variable GIT_ORG when running the script like:"
    echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

    exit 1
  fi
fi

if [[ -z ${OUTPUT_DIR} ]]; then
  echo "Please set the environment variable OUTPUT_DIR when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

  exit 1
fi
mkdir -p "${OUTPUT_DIR}"


CP_EXAMPLES=${CP_EXAMPLES:-false}
ACE_SCENARIO=${ACE_SCENARIO:-false}
MQ_SCENARIO=${MQ_SCENARIO:-false}
ACE_BOM_PATH=${ACE_BOM_PATH:-scripts/bom/ace}
CP_DEFAULT_TARGET_NAMESPACE=${CP_DEFAULT_TARGET_NAMESPACE:-tools}

GITOPS_PROFILE=${GITOPS_PROFILE:-0-bootstrap/single-cluster}

GIT_SRC_BASEURL=${GIT_SRC_BASEURL:-https://github.com}
GIT_SRC_ORG=${GIT_SRC_ORG:-cloud-native-toolkit}
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


IBM_CP_IMAGE_REGISTRY=${IBM_CP_IMAGE_REGISTRY:-cp.icr.io}
IBM_CP_IMAGE_REGISTRY_USER=${IBM_CP_IMAGE_REGISTRY_USER:-cp}

set_repo_list () { 
    echo "Setting list of repos to prepare"
    # Space separated of Source GIT url,target repo name,target directory name
    GITOPS_REPOS="${GIT_SRC_BASEURL}/${GIT_SRC_ORG}/multi-tenancy-gitops,multi-tenancy-gitops,gitops-0-bootstrap \
              ${GIT_SRC_BASEURL}/${GIT_SRC_ORG}/multi-tenancy-gitops-infra,multi-tenancy-gitops-infra,gitops-1-infra \
              ${GIT_SRC_BASEURL}/${GIT_SRC_ORG}/multi-tenancy-gitops-services,multi-tenancy-gitops-services,gitops-2-services"
    if [[ "${CP_EXAMPLES}" == "true" ]]; then
        GITOPS_REPOS=${GITOPS_REPOS}" ${GIT_SRC_BASEURL}/${GIT_SRC_ORG}-demos/multi-tenancy-gitops-apps,multi-tenancy-gitops-apps,gitops-3-apps"

        if [[ "${ACE_SCENARIO}" == "true" ]]; then
          GITOPS_REPOS=${GITOPS_REPOS}" ${GIT_SRC_BASEURL}/${GIT_SRC_ORG}/ace-customer-details,ace-customer-details,src-ace-app-customer-details"
        fi
        if [[ "${MQ_SCENARIO}" == "true" ]]; then
          GITOPS_REPOS=${GITOPS_REPOS}" ${GIT_SRC_BASEURL}/${GIT_SRC_ORG}/mq-infra,mq-infra,mq-infra  ${GIT_SRC_BASEURL}/${GIT_SRC_ORG}/mq-spring-app,mq-infra,mq-spring-app "
        fi
    fi
}

setup_gitea () {
    bash $(dirname "${BASH_SOURCE}")/gitea-install.sh
    # initialize gitea repos
    sleep 30
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

    # Creating the Organization 
    response=$(curl -k --write-out '%{http_code}' --silent --output /dev/null "${GITEA_BASEURL}/api/v1/orgs/${GIT_ORG}")
    if [[ "${response}" == "200" ]]; then
      echo "org already exists ${GIT_ORG}"
          # CAN NOT delete org with repos and recreating doesn't complain so don't check]
    else
      echo "Creating org for ${GITEA_BASEURL}/api/v1/orgs ${GIT_ORG}"
      curl -k -X POST -H "Content-Type: application/json" -d "{ \"username\": \"${GIT_ORG}\", \"visibility\": \"public\", \"url\": \"\"  }" "${GITEA_BASEURL}/api/v1/orgs"
    fi

    # Creating repos based on the GITOPS_REPOS list
    for i in ${GITOPS_REPOS}; do
        IFS=","
        set $i
        echo "Checking git repository ${GITEA_BASEURL}/${GIT_ORG}/$2.git"
        response=$(curl -k --write-out '%{http_code}' --silent --output /dev/null "${GITEA_BASEURL}/api/v1/repos/${GIT_ORG}/$2")
        if [[ "${response}" == "200" ]]; then
            echo "repo already exists ${GITEA_BASEURL}/${GIT_ORG}/$2.git"
        else
            echo "Creating repo for ${GITEA_BASEURL}/${GIT_ORG}/$2.git"
            curl -k -X POST -H "Content-Type: application/json" -d "{ \"name\": \"${2}\", \"default_branch\": \"${GITEA_BRANCH}\" }" "${GITEA_BASEURL}/api/v1/orgs/${GIT_ORG}/repos"
        fi
        unset IFS
    done

    GIT_BASEURL=${GITEA_BASEURL}
    GIT_GITOPS_BRANCH=${GITEA_GITOPS_BRANCH} 
    GIT_GITOPS_INFRA_BRANCH=${GITEA_GITOPS_INFRA_BRANCH} 
    GIT_GITOPS_SERVICES_BRANCH=${GITEA_GITOPS_SERVICES_BRANCH} 
    GIT_GITOPS_APPLICATIONS_BRANCH=${GITEA_GITOPS_APPLICATIONS_BRANCH} 

    # may need to check self signed repo then disable git ssl verify
    git config --global http.sslVerify false
}

setup_github () {
    pushd ${OUTPUT_DIR}
    GH=$(command -v gh)

    GIT_HOST=${GIT_HOST:-github.com}
    echo  "${GIT_TOKEN}" | "${GH}" auth login --hostname "${GIT_HOST}" --with-token

    IFS=" "
    for i in ${GITOPS_REPOS}; do
        IFS=","
        set $i
        set +e
        GHREPONAME=$("${GH}" api /repos/${GIT_ORG}/$2 -q .name || true)
        if [[ ! ${GHREPONAME} = "$2" ]]; then
            echo "Repo not found - creating ${GIT_BASEURL}/${GIT_ORG}/$2"
            "${GH}" repo create ${GIT_BASEURL}/${GIT_ORG}/$2 --public
        fi
        set -e
        unset IFS
    done

    popd
}

setup_gitlab () {

    GLAB=$(command -v glab)

    GIT_HOST=${GIT_HOST:-gitlab.com}
    "${GLAB}" auth login --hostname "${GIT_HOST}" --token "${GIT_TOKEN}"

    IFS=" "
    for i in ${GITOPS_REPOS}; do
        IFS=","
        set $i
        set +e
        "${GLAB}" repo view ${GIT_ORG}/$2 
        glRC=$?
        if [[ "${glRC}" -eq "1" ]]; then
            echo "Repo not found - creating ${GIT_BASEURL}/${GIT_ORG}/$2"
            "${GLAB}" repo create ${GIT_ORG}/$2 --public
        fi
        set -e
        unset IFS
    done
}

clone_repos () {
    echo "Github prefix is ${GIT_BASEURL}/${GIT_ORG}"

    pushd ${OUTPUT_DIR}
    IFS=" "
    # create repos
    for i in ${GITOPS_REPOS}; do
        IFS=","
        set $i

        set +e
        echo "Cloning repo $1 into ${GIT_BASEURL}/${GIT_ORG}/$2 branch ${GIT_BRANCH}"
        echo "Repo will be locally available in ${OUTPUT_DIR}/$3"

        if [[ -d $3 ]]; then
            remoteUrl=$(cat $3/.git/config 2>/dev/null | grep url | head -1 | cut -d" " -f3)
            if [[ "${remoteUrl}" == "${GIT_BASEURL}/${GIT_ORG}/$2" ]]; then 
                echo "${remoteUrl} is already cloned in $3"
                # check whether it is empty
                cd $3
                commits=$(git log 2>/dev/null | grep commit | wc -l)
                cd ..
                if [[ "$commits" -eq "0" ]]; then
                    echo "It is empty - will re-clone"
                    rm -rf $3
                else
                    continue
                fi
            else 
                echo "Repo belonging to $remoteUrl - must reclone"
                rm -rf $3
            fi
        fi
        # check if repo is populated
        git clone ${GIT_BASEURL}/${GIT_ORG}/$2 $3
        cd $3
        commits=$(git log 2>/dev/null | grep commit | wc -l)
        cd ..
        if [[ "$commits" -eq "0" ]]; then
            echo "It is empty - will re-clone"
            rm -rf $3

            git clone --depth 1 $1 $3
            cd $3
            rm -rf .git
            git init -b ${GIT_BRANCH}
            git config --local user.email "toolkit@cloudnativetoolkit.dev"
            git config --local user.name "IBM Cloud Native Toolkit"
            git add .
            git commit -m "initial commit"
            git remote add origin ${GIT_BASEURL}/${GIT_ORG}/$2.git
            git push --tags --set-upstream origin ${GIT_BRANCH}
            cd ..
        fi

        echo "Repo ${GIT_BASEURL}/${GIT_ORG}/$2 branch ${GIT_BRANCH} initialized"

        set -e

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
        popd
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
  set +e
  if [[ "${GITOPS_PROFILE}" == "0-bootstrap/single-cluster" ]]; then
    rm -r 0-bootstrap/others
  fi

  GIT_BRANCH=${GIT_BRANCH} GIT_ORG=${GIT_ORG} GIT_BASEURL=${GIT_BASEURL} ./scripts/set-git-source.sh
  # if [[ ${GIT_TOKEN} ]]; then
  #   git remote set-url origin ${GIT_PROTOCOL}://${GIT_TOKEN}@${GIT_HOST}/${GIT_ORG}/${GIT_GITOPS}
  # elif [[ ${USE_GITEA} == "true" ]]; then
  #   git remote set-url origin ${GITEA_BASEURL}/${GIT_ORG}/${GIT_GITOPS}
  # fi
  git add .
  git commit -m "Updating git source to ${GIT_ORG} with ${GIT_BRANCH}"
  git push origin
  set -e
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
    echo "# The Cloud Pak console and admin password"
    echo "oc get route -n ${CP_DEFAULT_TARGET_NAMESPACE} integration-navigator-pn -o template --template='https://{{.spec.host}}'"
    echo "oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_username,admin_password --to=-"
    echo "# -----"
    if [[ "${USE_GITEA}" == "true" ]]; then
        echo "# Gitea UI: $(oc get route ${INSTANCE_NAME} -n ${TOOLKIT_NAMESPACE}${INSTANCE_NAME} -n ${TOOLKIT_NAMESPACE} -o template --template='https://{{.spec.host}}')"
        echo "# "
        echo "# To get the Gitea admin ID and admin password:"
        echo "# -----"
        echo "oc extract secrets/${INSTANCE_NAME}-access --keys=username,password -n ${TOOLKIT_NAMESPACE} --to=-"
        echo "# -----"
    fi
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
echo "Processing bootstrap to ${GIT_TARGET}"

set_repo_list

if [[ "${GIT_TARGET}" == "github" ]]; then 
    setup_github
elif [[ "${GIT_TARGET}" == "gitea" ]]; then 
    setup_gitea
elif [[ "${GIT_TARGET}" == "gitlab" ]]; then 
    setup_gitlab
elif [[ "${GIT_TARGET}" == "github.ibm" ]]; then 
    echo "IBM Github is not implemented yet"
    exit 999
fi

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
get_rwx_storage_class
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
