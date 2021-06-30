#!/usr/bin/env bash

set -euo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOTDIR="$(cd ${SCRIPTDIR}/..; pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

GIT_REPO=${GIT_REPO:-multi-tenancy-gitops}
GIT_USER=${GIT_USER}
if [ -z ${GIT_USER} ]; then echo "Please set GIT_USER when running script"; exit 1; fi
GIT_PAT=${GIT_PAT}
if [ -z ${GIT_PAT} ]; then echo "Please set GIT_PAT (GH Personal Access Token) that has admin:repo_hook privileges when running script"; exit 1; fi

export ARGOHOST="$(oc get route argocd-cluster-server -o jsonpath='{ .spec.host }' -n openshift-gitops)"

curl \
  --verbose \
  -u $GIT_USER:$GIT_PAT \
  -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$GIT_USER/$GIT_REPO/hooks \
  -d '{
      "name":"web",
      "config": {
          "url":"https://'"$ARGOHOST"'/api/webhook",
          "content_type":"json",
          "insecure_ssl":"1"
       }
      }'