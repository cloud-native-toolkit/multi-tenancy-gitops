# Deploy the Cloud-Native Toolkit

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ci.yaml
    - argocd/namespace-dev.yaml
    - argocd/namespace-staging.yaml
    - argocd/namespace-prod.yaml
    - argocd/namespace-tools.yaml
    ```
### Services - Kustomization.yaml    
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/instances/artifactory.yaml
    - argocd/instances/developer-dashboard.yaml
    - argocd/instances/swaggereditor.yaml
    - argocd/instances/sonarqube.yaml
    - argocd/instances/pact-broker.yaml
    ```
