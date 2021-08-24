#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

GIT_USER=${GIT_USER}
if [ -z ${GIT_USER} ]; then echo "Please set GIT_USER when running script"; exit 1; fi
set -u

echo "If you do not set GIT_BRANCH_MQ_REPO and GIT_BRANCH_APP_REPO variables, by default those will be master"

GIT_BRANCH_MQ_REPO=${GIT_BRANCH_MQ_REPO:-master}
GIT_BRANCH_APP_REPO=${GIT_BRANCH_APP_REPO:-master}

echo "Setting the git user to ${GIT_USER}"
echo "Setting the git branch to ${GIT_BRANCH_MQ_REPO}"

find ${SCRIPTDIR}/.. -name '*.yaml' -print0 |
  while IFS= read -r -d '' File; do
    if grep -q "kind: EventListener" "$File"; then
      echo "$File"
      sed -i'.bak' -e "s#body.ref == 'refs/heads/master' \&\& body.repository.full_name == 'cloud-native-toolkit/mq-infra'#body.ref == 'refs/heads/${GIT_BRANCH_MQ_REPO}' \&\& body.repository.full_name == '${GIT_USER}/mq-infra'#" $File
      sed -i'.bak' -e "s#body.ref == 'refs/heads/master' \&\& body.repository.full_name == 'cloud-native-toolkit/mq-spring-app'#body.ref == 'refs/heads/${GIT_BRANCH_APP_REPO}' \&\& body.repository.full_name == '${GIT_USER}/mq-spring-app'#" $File
      rm "${File}.bak"
    fi
  done

echo "git commit and push changes now"
