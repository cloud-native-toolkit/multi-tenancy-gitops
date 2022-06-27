#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x


if [ -z ${GIT_ORG} ]; then echo "Please set GIT_ORG when running script, optional GIT_BASEURL and GIT_REPO to formed the git url GIT_BASEURL/GIT_ORG/*"; exit 1; fi

set -u

GIT_BRANCH=${GIT_BRANCH:-master}
GIT_BASEURL=${GIT_BASEURL:-https://github.com}
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

echo "Setting kustomization patches to ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_INFRA} on branch ${GIT_GITOPS_INFRA_BRANCH}"
echo "Setting kustomization patches to ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_SERVICES} on branch ${GIT_GITOPS_SERVICES_BRANCH}"

find ${SCRIPTDIR}/../0-bootstrap/single-cluster/1-infra -name 'kustomization.yaml' -print0 |
  while IFS= read -r -d '' File; do
    if grep -q "argocd/namespace-ibm-common-services.yaml" "$File"; then
      echo "estoy haciendo un sed en $File"
      sed -i '.bak' -e 's/#- argocd\/namespace-ibm-common-services.yaml/\- argocd\/namespace-ibm-common-services.yaml/g' $File
      sed -i '.bak' -e 's/#- argocd\/namespace-tools.yaml/\- argocd\/namespace-tools.yaml/g' $File
      sed -i '.bak' -e 's/#- argocd\/serviceaccounts-tools.yaml/\- argocd\/serviceaccounts-tools.yaml/g' $File
      sed -i '.bak' -e 's/#- argocd\/scc-wkc-iis.yaml/\- argocd\/scc-wkc-iis.yaml/g' $File
      rm "${File}.bak"
    fi
  done

find ${SCRIPTDIR}/../0-bootstrap/single-cluster/2-services -name 'kustomization.yaml' -print0 |
  while IFS= read -r -d '' File; do
     if grep -q "argocd/operators/ibm-cpd-scheduling-operator.yaml" "$File"; then
       echo "estoy haciendo un sed en $File"
       sed -i '.bak' -e 's/#- argocd\/operators\/ibm-cpd-scheduling-operator.yaml/\- argocd\/operators\/ibm-cpd-scheduling-operator.yaml/g' $File
       sed -i '.bak' -e 's/#- argocd\/operators\/ibm-cpd-platform-operator.yaml/\- argocd\/operators\/ibm-cpd-platform-operator.yaml/g' $File
       sed -i '.bak' -e 's/#- argocd\/instances\/ibm-cpd-instance.yaml/\- argocd\/instances\/ibm-cpd-instance.yaml/g' $File
       sed -i '.bak' -e 's/#- argocd\/operators\/ibm-cpd-wkc-operator.yaml/\- argocd\/operators\/ibm-cpd-wkc-operator.yaml/g' $File
       sed -i '.bak' -e 's/#- argocd\/instances\/ibm-cpd-wkc-instance.yaml/\- argocd\/instances\/ibm-cpd-wkc-instance.yaml/g' $File
       sed -i '.bak' -e 's/#- argocd\/operators\/ibm-cpd-ds-operator.yaml/\- argocd\/operators\/ibm-cpd-ds-operator.yaml/g' $File
       sed -i '.bak' -e 's/#- argocd\/instances\/ibm-cpd-ds-instance.yaml/\- argocd\/instances\/ibm-cpd-ds-instance.yaml/g' $File
       sed -i '.bak' -e 's/#- argocd\/operators\/ibm-catalogs.yaml/\- argocd\/operators\/ibm-catalogs.yaml/g' $File
       rm "${File}.bak"
     fi
   done
echo "done replacing variables in kustomization.yaml files"
echo "git commit and push changes now"