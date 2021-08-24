#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

GIT_USER=${GIT_ORG}
if [ -z ${GIT_ORG} ]; then echo "Please set GIT_ORG when running script, optional GIT_BASEURL and GIT_REPO to formed the git url GIT_BASEURL/GIT_ORG/*"; exit 1; fi
if [ -z ${GIT_BRANCH} ]; then echo "Please set GIT_BRANCH when running script"; exit 1; fi

set -u

GIT_BASEURL=${GIT_BASEURL:-https://github.com}
GIT_GITOPS=${GIT_GITOPS:-multi-tenancy-gitops.git}
GIT_GITOPS_INFRA=${GIT_GITOPS_INFRA:-multi-tenancy-gitops-infra.git}
GIT_GITOPS_SERVICES=${GIT_GITOPS_SERVICES:-multi-tenancy-gitops-services.git}
GIT_GITOPS_APPLICATIONS=${GIT_GITOPS_APPLICATIONS:-multi-tenancy-gitops-apps.git}


echo "Setting source git repos to ${GIT_BASEURL}/${GIT_ORG} on branch ${GIT_BRANCH}"

find ${SCRIPTDIR}/../0-bootstrap -name '*.yaml' -print0 |
  while IFS= read -r -d '' File; do
    if grep -q "kind: Application\|kind: AppProject" "$File"; then
      echo "$File"
      sed -i'.bak' -e "s#\${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS}#${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS}#" $File
      sed -i'.bak' -e "s#\${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_INFRA}#${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_INFRA}#" $File
      sed -i'.bak' -e "s#\${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_SERVICES}#${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_SERVICES}#" $File
      sed -i'.bak' -e "s#\${GIT_BASEURL}/\${GIT_ORG}/\${GIT_GITOPS_APPLICATIONS}#${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_APPLICATIONS}#" $File
      sed -i'.bak' -e "s#\${GIT_BRANCH}#${GIT_BRANCH}#" $File
      rm "${File}.bak"
    fi
  done

echo "git commit and push changes now"
