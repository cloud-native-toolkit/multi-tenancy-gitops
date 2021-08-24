#!/usr/bin/env bash

OUTPUT_DIR=$(mktemp -d)

cat ./scripts/bootstrap.sh | \
GIT_USER=csantanapr \
GIT_ORG=csantanapr-test-gitops-2 \
GIT_TOKEN=2bc888075259e313b08505722c3c80f19301d1d4 \
OUTPUT_DIR=${OUTPUT_DIR} \
GIT_GITOPS_BRANCH=kustomize-patches \
DEBUG=true \
sh

echo "code ${OUTPUT_DIR}"
echo "rm -r ${OUTPUT_DIR}"

exit 0