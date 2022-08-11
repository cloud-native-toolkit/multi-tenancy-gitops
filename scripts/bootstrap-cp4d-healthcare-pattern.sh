#!/usr/bin/env bash

set -eo pipefail

USE_CP4D_HEALTHCARE_PATTERN=${CP4D_HCARE_PATTERN}
USE_GITEA=${USE_GITEA:-false}

if [[ "${USE_GITEA}" == "true" ]]; then
  exec $(dirname "${BASH_SOURCE}")/bootstrap-gitea.sh
fi

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
  echo "We recommend to create a new github organization for all your gitops repos"
  echo "Setup a new organization on github https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch"
  echo "Please set the environment variable GIT_ORG when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

  exit 1
fi

if [[ -z ${OUTPUT_DIR} ]]; then
  echo "Please set the environment variable OUTPUT_DIR when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

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

fork_repos () {
    echo "Github user/org is ${GIT_ORG}"

    pushd ${OUTPUT_DIR}

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops" ]]; then
      echo "Fork not found, creating fork and cloning"
      gh repo fork cloud-native-toolkit/multi-tenancy-gitops --clone --org ${GIT_ORG} --remote
      mv multi-tenancy-gitops gitops-0-bootstrap
    elif [[ ! -d gitops-0-bootstrap ]]; then
      echo "Fork found, repo not cloned, cloning repo"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops gitops-0-bootstrap
    fi
    cd gitops-0-bootstrap
    git remote set-url --push upstream no_push
    git checkout ${GIT_GITOPS_BRANCH} || git checkout --track origin/${GIT_GITOPS_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-infra -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-infra" ]]; then
      echo "Fork not found, creating fork and cloning"
      gh repo fork cloud-native-toolkit/multi-tenancy-gitops-infra --clone --org ${GIT_ORG} --remote
      mv multi-tenancy-gitops-infra gitops-1-infra
    elif [[ ! -d gitops-1-infra ]]; then
      echo "Fork found, repo not cloned, cloning repo"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-infra gitops-1-infra
    fi
    cd gitops-1-infra
    git remote set-url --push upstream no_push
    git checkout ${GIT_GITOPS_INFRA_BRANCH} || git checkout --track origin/${GIT_GITOPS_INFRA_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-services -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-services" ]]; then
      echo "Fork not found, creating fork and cloning"
      gh repo fork cloud-native-toolkit/multi-tenancy-gitops-services --clone --org ${GIT_ORG} --remote
      mv multi-tenancy-gitops-services gitops-2-services
    elif [[ ! -d gitops-2-services ]]; then
      echo "Fork found, repo not cloned, cloning repo"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-services gitops-2-services
    fi
    cd gitops-2-services
    git remote set-url --push upstream no_push
    git checkout ${GIT_GITOPS_SERVICES_BRANCH} || git checkout --track origin/${GIT_GITOPS_SERVICES_BRANCH}
    cd ..

    if [[ "${CP_EXAMPLES}" == "true" ]]; then
      echo "Creating repos for Cloud Pak examples"

      GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-apps -q .name || true)
      if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-apps" ]]; then
        echo "Fork not found, creating fork and cloning"
        gh repo fork cloud-native-toolkit-demos/multi-tenancy-gitops-apps --clone --org ${GIT_ORG} --remote
        mv multi-tenancy-gitops-apps gitops-3-apps
      elif [[ ! -d gitops-3-apps ]]; then
        echo "Fork found, repo not cloned, cloning repo"
        gh repo clone ${GIT_ORG}/multi-tenancy-gitops-apps gitops-3-apps
      fi
      cd gitops-3-apps
      git remote set-url --push upstream no_push
      git checkout ${GIT_GITOPS_APPLICATIONS_BRANCH} || git checkout --track origin/${GIT_GITOPS_APPLICATIONS_BRANCH}
      cd ..

      if [[ "${ACE_SCENARIO}" == "true" ]]; then
        GHREPONAME=$(gh api /repos/${GIT_ORG}/ace-customer-details -q .name || true)
        if [[ ! ${GHREPONAME} = "ace-customer-details" ]]; then
          echo "Fork not found, creating fork and cloning"
          gh repo fork cloud-native-toolkit-demos/ace-customer-details --clone --org ${GIT_ORG} --remote
          mv ace-customer-details src-ace-app-customer-details
        elif [[ ! -d src-ace-app-customer-details ]]; then
          echo "Fork found, repo not cloned, cloning repo"
          gh repo clone ${GIT_ORG}/ace-customer-details src-ace-app-customer-details
        fi
        cd src-ace-app-customer-details
        git remote set-url --push upstream no_push
        git checkout master || git checkout --track origin/master
        cd ..
      fi

    fi

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
    oc create ns ${GIT_GITOPS_NAMESPACE} || true
    oc apply -f gitops-0-bootstrap/setup/ocp4x/
    while ! oc wait crd applications.argoproj.io --timeout=-1s --for=condition=Established  2>/dev/null; do sleep 30; done
    sleep 60
    while ! oc wait pod --timeout=30s --for=condition=Ready --all -n ${GIT_GITOPS_NAMESPACE} > /dev/null; do sleep 30; done
    popd
}

# NC: No need to remove default instance since its not created anymore
#     Handled with DISABLE_DEFAULT_ARGOCD_INSTANCE = True in openshift-gitops-operator.yaml
#
# delete_default_argocd_instance () {
#     echo "Delete the default ArgoCD instance"
#     pushd ${OUTPUT_DIR}
#     oc delete gitopsservice cluster -n ${GIT_GITOPS_NAMESPACE} || true
#     popd
# }

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
  echo setting git source instead of git override
  pushd ${OUTPUT_DIR}/gitops-0-bootstrap

  if [[ "${GITOPS_PROFILE}" == "0-bootstrap/single-cluster" ]]; then
    test -e 0-bootstrap/others && rm -r 0-bootstrap/others
  fi

  GIT_ORG=${GIT_ORG} GIT_GITOPS_NAMESPACE=${GIT_GITOPS_NAMESPACE} source ./scripts/set-git-source.sh
  if [[ ${GIT_TOKEN} ]]; then
    git remote set-url origin ${GIT_PROTOCOL}://${GIT_TOKEN}@${GIT_HOST}/${GIT_ORG}/${GIT_GITOPS}
  fi
  set +e
  git add .
  git commit -m "Updating git source to ${GIT_ORG}"
  git push origin
  set -e
  popd
}

set-git-cp4d-healthcare-pattern () {
  echo setting git source instead of git override
  pushd ${OUTPUT_DIR}/gitops-0-bootstrap

  # --------------------------------------------------  Start refactor - move to a script   --------------------------------------
  # (OM) ToDo: Move the sed's commands to the following scripts
  # GIT_ORG=${GIT_ORG} GIT_GITOPS_NAMESPACE=${GIT_GITOPS_NAMESPACE} source ./scripts/set-git-cp4d-healthcare-pattern.sh
  # if [[ ${GIT_TOKEN} ]]; then
  #   git remote set-url origin ${GIT_PROTOCOL}://${GIT_TOKEN}@${GIT_HOST}/${GIT_ORG}/${GIT_GITOPS}
  # fi
  find 0-bootstrap/single-cluster -name 'kustomization.yaml' -print0 |
    while IFS= read -r -d '' File; do
      if grep -q "namespace-ibm-common-services.yaml" "$File"; then
        sed -i'.bak' -e "s_#- argocd/namespace-ibm-common-services.yaml_- argocd/namespace-ibm-common-services.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/namespace-tools.yaml_- argocd/namespace-tools.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/serviceaccounts-tools.yaml_- argocd/serviceaccounts-tools.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/scc-wkc-iis.yaml_- argocd/scc-wkc-iis.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/norootsquash.yaml_- argocd/norootsquash.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/daemonset-sync-global-pullsecret.yaml_- argocd/daemonset-sync-global-pullsecret.yaml_" $File
        rm "${File}.bak"
      fi
      if grep -q "ibm-cpd-scheduling-operator.yaml" "$File"; then
        sed -i'.bak' -e "s_#- argocd/operators/ibm-cpd-scheduling-operator.yaml_- argocd/operators/ibm-cpd-scheduling-operator.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-cpd-platform-operator.yaml_- argocd/operators/ibm-cpd-platform-operator.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/ibm-cpd-instance.yaml_- argocd/instances/ibm-cpd-instance.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-cpd-wkc-operator.yaml_- argocd/operators/ibm-cpd-wkc-operator.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/ibm-cpd-wkc-instance.yaml_- argocd/instances/ibm-cpd-wkc-instance.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-cpd-ds-operator.yaml_- argocd/operators/ibm-cpd-ds-operator.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/ibm-cpd-ds-instance.yaml_- argocd/instances/ibm-cpd-ds-instance.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-catalogs.yaml_- argocd/operators/ibm-catalogs.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-cpd-dv-operator.yaml_- argocd/operators/ibm-cpd-dv-operator.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/ibm-cpd-dv-instance.yaml_- argocd/instances/ibm-cpd-dv-instance.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/cp4d-pattern-healthcare.yaml_- argocd/instances/cp4d-pattern-healthcare.yaml_" $File
        rm "${File}.bak"
      fi
    done
  # --------------------------------------------------  End refactor - move to a script   --------------------------------------

  if [[ ${GIT_TOKEN} ]]; then
    git remote set-url origin ${GIT_PROTOCOL}://${GIT_TOKEN}@${GIT_HOST}/${GIT_ORG}/${GIT_GITOPS}
  fi

  set +e

  git add .

  git commit -m "Updating git source for cp4d to ${GIT_ORG}"

  git push origin

  set -e

  popd
}

deploy_bootstrap_argocd () {
  echo "Deploying top level bootstrap ArgoCD Application for cluster profile ${GITOPS_PROFILE}"
  pushd ${OUTPUT_DIR}
  oc apply -n ${GIT_GITOPS_NAMESPACE} -f gitops-0-bootstrap/${GITOPS_PROFILE}/bootstrap.yaml
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

fork_repos

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

#delete_default_argocd_instance

create_custom_argocd_instance

patch_argocd_tls

# Either you map the GIT source using set_git_source or using argocd_git_override - but not both

#create_argocd_git_override_configmap
#apply_argocd_git_override_configmap
#argocd_git_override

set_git_source

# (OM) Add infra and servives for CP4D
USE_CP4D_HEALTHCARE_PATTERN=${CP4D_HCARE_PATTERN}

if [[ "${USE_CP4D_HEALTHCARE_PATTERN}" == "true" ]]; then
  set-git-cp4d-healthcare-pattern
fi
# set_git_source_cp4d

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

exit 0
