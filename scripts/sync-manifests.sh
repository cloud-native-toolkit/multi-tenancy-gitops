#!/usr/bin/env bash

set -euo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOTDIR="$(cd ${SCRIPTDIR}/..; pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

cd ${SCRIPTDIR}/..

for LAYER in 1-infra 2-services 3-apps
do

    for CLUSTER in 1-shared-cluster/cluster-1-cicd-dev-stage-prod 1-shared-cluster/cluster-n-prod 2-isolated-cluster/cluster-1-cicd-dev-stage 2-isolated-cluster/cluster-n-prod 3-multi-cluster/cluster-1-cicd 3-multi-cluster/cluster-2-dev 3-multi-cluster/cluster-3-stage 3-multi-cluster/cluster-n-prod
    do
        test -e 0-bootstrap/others/${CLUSTER}/${LAYER}/argocd && {
            rm -r 0-bootstrap/others/${CLUSTER}/${LAYER}/argocd
        }
        test -e 0-bootstrap/single-cluster && test -e 0-bootstrap/others && {
            cp -a 0-bootstrap/single-cluster/${LAYER}/{argocd,${LAYER}.yaml,kustomization.yaml} 0-bootstrap/others/${CLUSTER}/${LAYER}/
        }
    done

done
