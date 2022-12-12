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

find ${SCRIPTDIR}/../0-bootstrap/single-cluster -name 'kustomization.yaml' -print0 |
    while IFS= read -r -d '' File; do
      if grep -q "namespace-ibm-common-services.yaml" "$File"; then
        sed -i'.bak' -e "s_#- argocd/namespace-ibm-common-services.yaml_- argocd/namespace-ibm-common-services.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/namespace-tools.yaml_- argocd/namespace-tools.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/consolenotification.yaml_- argocd/consolenotification.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/namespace-openshift-serverless.yaml_- argocd/namespace-openshift-serverless.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/namespace-knative-eventing.yaml_- argocd/namespace-knative-eventing.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/namespace-knative-serving.yaml_- argocd/namespace-knative-serving.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/namespace-knative-serving-ingress.yaml_- argocd/namespace-knative-serving-ingress.yaml_" $File
        rm "${File}.bak"
      fi
      if grep -q "ibm-cp4s-operator.yaml" "$File"; then
        sed -i'.bak' -e "s_#- argocd/operators/ibm-cp4s-operator.yaml_- argocd/operators/ibm-cp4s-operator.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-foundations.yaml_- argocd/operators/ibm-foundations.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-automation-foundation-core-operator.yaml_- argocd/operators/ibm-automation-foundation-core-operator.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/ibm-catalogs.yaml_- argocd/operators/ibm-catalogs.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/operators/openshift-serverless.yaml_- argocd/operators/openshift-serverless.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/ibm-cp4sthreatmanagements-instance.yaml_- argocd/instances/ibm-cp4sthreatmanagements-instance.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/ibm-foundational-services-instance.yaml_- argocd/instances/ibm-foundational-services-instance.yaml_" $File
        sed -i'.bak' -e "s_#- argocd/instances/openshift-serverless-knative-serving-instance.yaml_- argocd/instances/openshift-serverless-knative-serving-instance.yaml_" $File
        rm "${File}.bak"
      fi
    done

echo "done replacing variables in kustomization.yaml files for CP4S"
echo "git commit and push changes now"