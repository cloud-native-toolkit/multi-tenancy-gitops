#!/usr/bin/env bash

set -euo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOTDIR="$(cd ${SCRIPTDIR}/..; pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

cp ${ROOTDIR}/0-bootstrap/argocd/inactive/1-infra.yaml ${ROOTDIR}/0-bootstrap/argocd/active
GIT_MESSAGE="enable infra"
source ${SCRIPTDIR}/git-add-commit-push.sh
