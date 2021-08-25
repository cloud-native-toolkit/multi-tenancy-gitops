# Cloud Native Toolkit GitOps Production Deployment Guides

- This repository shows the reference architecture for gitops directory structure for more info https://cloudnativetoolkit.dev/learning/gitops-int/gitops-with-cloud-native-toolkit


### TLDR

1. Create new repositories using these git repositories as templates
    - https://github.com/cloud-native-toolkit/multi-tenancy-gitops  <== this repository
    - https://github.com/cloud-native-toolkit/multi-tenancy-gitops-infra
    - https://github.com/cloud-native-toolkit/multi-tenancy-gitops-services
    - https://github.com/cloud-native-toolkit/multi-tenancy-gitops-apps
1. Select a profile and delete the others from the `0-bootstrap` directory. For example `single-cluster`
1. Run script to replace the git url and branch to your git organization where you created the git repositories
    ```bash
    GIT_ORG=acme-org GIT_BRANCH=master ./script/set-git-sources.sh
    ```
1. Commit and push changes to your git repository
    ```bash
    git add .
    git commit -m "intial boostrap setup"
    git push origin
    ```
1. Apply ArgoCD Bootstrap Application
    ```bash
    oc apply -f 0-bootstrap/single-cluster/bootstrap.yaml
    ```
1. Deploy ArgoCD Applications for each layer by uncommenting the lines in `kustomization.yaml` files
    - 0-bootstrap/single-cluster/1-infra/kustomization.yaml
    - 0-bootstrap/single-cluster/2-services/kustomization.yaml
    - 0-bootstrap/single-cluster/1-apps/kustomization.yaml
1. Commit and push changes to your git repository


