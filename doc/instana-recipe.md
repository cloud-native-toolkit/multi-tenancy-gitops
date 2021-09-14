# Deploy Instana

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and uncomment the following:
    ```yaml
    - argocd/namespace-instana-agent.yaml
    ```
### Services - Kustomization.yaml    
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/instances/instana-agent.yaml
    ```
1. Update the helm/values as needed in the `argocd/instances/instana-agent.yaml` file as defined in the Instana prerequisits section [here](https://github.com/cloud-native-toolkit/multi-tenancy-gitops-services#instana)
