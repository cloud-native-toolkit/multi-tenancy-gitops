#!/usr/bin/env bash

set -eo pipefail

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

gh_version_long=$(gh --version | grep version | sed 's/gh version //g' | sed 's/ .*//g')
gh_version=$(echo ${gh_version_long} | sed 's/.[0-9]$//g')
min_req_gh_version="2.5"

echo "Your Github CLI (gh) version is: ${gh_version_long}"

if [ 1 -eq "$(echo "${gh_version} < ${min_req_gh_version}" | bc)" ]
then  
    echo "--> We recommend you to have your GitHub CLI (gh) version to ${min_req_gh_version} or newer to avoid errors in this script."
    echo "--> You can check your GitHub CLI (gh) version executing: gh --version."
    echo "--> You can find more information about the GitHub CLI (gh) in https://github.com/cli/cli"
fi

set +e
oc version --client | grep '4.7\|4.8'
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
else
  echo "Creating GitHub repositories and local clones in folder:" ${OUTPUT_DIR}
fi
mkdir -p "${OUTPUT_DIR}"

CP_EXAMPLES=${CP_EXAMPLES:-true}
ACE_SCENARIO=${ACE_SCENARIO:-false}
ACE_BOM_PATH=${ACE_BOM_PATH:-scripts/bom/ace}
CP_DEFAULT_TARGET_NAMESPACE=${CP_DEFAULT_TARGET_NAMESPACE:-tools}

GITOPS_PROFILE=${GITOPS_PROFILE:-0-bootstrap/single-cluster}

GIT_BRANCH=${GIT_BRANCH:-master}
GIT_PROTOCOL=${GIT_PROTOCOL:-https}
GIT_HOST=${GIT_HOST:-github.com}
GIT_BASEURL=${GIT_BASEURL:-${GIT_PROTOCOL}://${GIT_HOST}}
GIT_GITOPS=${GIT_GITOPS:-multi-tenancy-gitops.git}
GIT_GITOPS_NAME=multi-tenancy-gitops
GIT_GITOPS_BRANCH=${GIT_GITOPS_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_INFRA=${GIT_GITOPS_INFRA:-multi-tenancy-gitops-infra.git}
GIT_GITOPS_INFRA_BRANCH=${GIT_GITOPS_INFRA_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_INFRA_NAME=multi-tenancy-gitops-infra
GIT_GITOPS_SERVICES=${GIT_GITOPS_SERVICES:-multi-tenancy-gitops-services.git}
GIT_GITOPS_SERVICES_BRANCH=${GIT_GITOPS_SERVICES_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_SERVICES_NAME=multi-tenancy-gitops-services
GIT_GITOPS_APPLICATIONS=${GIT_GITOPS_APPLICATIONS:-multi-tenancy-gitops-apps.git}
GIT_GITOPS_APPLICATIONS_BRANCH=${GIT_GITOPS_APPLICATIONS_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_APPLICATIONS_NAME=multi-tenancy-gitops-apps
GIT_GITOPS_ACE_SCENARIO_NAME=ace-customer-details
NEW_FOLDERS=${NEW_FOLDERS}

if [ -z ${NEW_FOLDERS} ]; then
  LOCAL_FOLDER_0="multi-tenancy-gitops"
  LOCAL_FOLDER_1="multi-tenancy-gitops-infra"
  LOCAL_FOLDER_2="multi-tenancy-gitops-services"
  LOCAL_FOLDER_3="multi-tenancy-gitops-apps"
  LOCAL_FOLDER_4="ace-customer-details"
else
  LOCAL_FOLDER_0="gitops-0-bootstrap"
  LOCAL_FOLDER_1="gitops-1-infra"
  LOCAL_FOLDER_2="gitops-2-services"
  LOCAL_FOLDER_3="gitops-3-apps"
  LOCAL_FOLDER_4="src-ace-app-customer-details"
fi

create_repos () {
    echo "Github user/org is ${GIT_ORG}"

    pushd ${OUTPUT_DIR}

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops" ]]; then
      echo "Repository ${GIT_GITOPS_NAME} not found, creating from template and cloning"
      gh repo create ${GIT_ORG}/multi-tenancy-gitops --public --template https://github.com/cloud-native-toolkit/multi-tenancy-gitops
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops
      if [ ! -z ${NEW_FOLDERS} ]; then
        mv multi-tenancy-gitops ${LOCAL_FOLDER_0}
      fi
    elif [[ ! -d ${LOCAL_FOLDER_0} ]]; then
      echo "Repository ${GIT_GITOPS_NAME} found but not cloned... cloning repository"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops ${LOCAL_FOLDER_0}
    else
      echo "Repository ${GIT_GITOPS_NAME} exists and already cloned... nothing to do"
    fi
    cd ${LOCAL_FOLDER_0}
    git checkout ${GIT_GITOPS_BRANCH} || git checkout --track origin/${GIT_GITOPS_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-infra -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-infra" ]]; then
      echo "Repository not found for ${GIT_GITOPS_INFRA_NAME}; creating from template and cloning"
      gh repo create ${GIT_ORG}/multi-tenancy-gitops-infra --public --template https://github.com/cloud-native-toolkit/multi-tenancy-gitops-infra
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-infra
      if [ ! -z ${NEW_FOLDERS} ]; then
        mv multi-tenancy-gitops-infra ${LOCAL_FOLDER_1}
      fi
    elif [[ ! -d ${LOCAL_FOLDER_1} ]]; then
      echo "Repository ${GIT_GITOPS_INFRA_NAME} found but not cloned... cloning repository"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-infra ${LOCAL_FOLDER_1}
    else
      echo "Repository ${GIT_GITOPS_INFRA_NAME} exists and already cloned... nothing to do"
    fi
    cd ${LOCAL_FOLDER_1}
    git checkout ${GIT_GITOPS_INFRA_BRANCH} || git checkout --track origin/${GIT_GITOPS_INFRA_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-services -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-services" ]]; then
      echo "Repository ${GIT_GITOPS_SERVICES_NAME} not found, creating from template and cloning"
      gh repo create ${GIT_ORG}/multi-tenancy-gitops-services --public --template https://github.com/cloud-native-toolkit/multi-tenancy-gitops-services
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-services
      if [ ! -z ${NEW_FOLDERS} ]; then
        mv multi-tenancy-gitops-services ${LOCAL_FOLDER_2}
      fi
    elif [[ ! -d ${LOCAL_FOLDER_2} ]]; then
      echo "Repository ${GIT_GITOPS_SERVICES_NAME} found but not cloned... cloning repository"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-services ${LOCAL_FOLDER_2}
    else
      echo "Repository ${GIT_GITOPS_SERVICES_NAME} exists and already cloned... nothing to do"
    fi
    cd ${LOCAL_FOLDER_2}
    git checkout ${GIT_GITOPS_SERVICES_BRANCH} || git checkout --track origin/${GIT_GITOPS_SERVICES_BRANCH}
    cd ..

    if [[ "${CP_EXAMPLES}" == "true" ]]; then
      echo "Creating repos for Cloud Pak examples"

      GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-apps -q .name || true)
      if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-apps" ]]; then
        echo "Repository ${GIT_GITOPS_APPLICATIONS_NAME} not found, creating from template and cloning"
        gh repo create ${GIT_ORG}/multi-tenancy-gitops-apps --public --template https://github.com/cloud-native-toolkit-demos/multi-tenancy-gitops-apps
        gh repo clone ${GIT_ORG}/multi-tenancy-gitops-apps
        if [ ! -z ${NEW_FOLDERS} ]; then
          mv multi-tenancy-gitops-apps ${LOCAL_FOLDER_3}
        fi
      elif [[ ! -d ${LOCAL_FOLDER_3} ]]; then
        echo "Repository ${GIT_GITOPS_APPLICATIONS_NAME} found but not cloned... cloning repository"
        gh repo clone ${GIT_ORG}/multi-tenancy-gitops-apps ${LOCAL_FOLDER_3}
      else
        echo "Repository ${GIT_GITOPS_APPLICATIONS_NAME} exists and already cloned... nothing to do"
      fi
      cd ${LOCAL_FOLDER_3}
      git checkout ${GIT_GITOPS_APPLICATIONS_BRANCH} || git checkout --track origin/${GIT_GITOPS_APPLICATIONS_BRANCH}
      cd ..

      if [[ "${ACE_SCENARIO}" == "true" ]]; then
        GHREPONAME=$(gh api /repos/${GIT_ORG}/ace-customer-details -q .name || true)
        if [[ ! ${GHREPONAME} = "ace-customer-details" ]]; then
          echo "Repository not found for ${GIT_GITOPS_ACE_SCENARIO_NAME}; creating from template and cloning"
          gh repo create ${GIT_ORG}/ace-customer-details --public --template https://github.com/cloud-native-toolkit-demos/ace-customer-details
          gh repo clone ${GIT_ORG}/ace-customer-details
          if [ ! -z ${NEW_FOLDERS} ]; then
            mv ace-customer-details ${LOCAL_FOLDER_4}
          fi
        elif [[ ! -d ${LOCAL_FOLDER_4} ]]; then
          echo "Repository ${GIT_GITOPS_ACE_SCENARIO_NAME} found but not cloned... cloning repository"
          gh repo clone ${GIT_ORG}/ace-customer-details ${LOCAL_FOLDER_4}
        else
          echo "Repository ${GIT_GITOPS_ACE_SCENARIO_NAME} exists and already cloned... nothing to do"
        fi
        cd ${LOCAL_FOLDER_4}
        git checkout master || git checkout --track origin/master
        cd ..
      fi

    fi

    popd

}

# main

create_repos

exit 0