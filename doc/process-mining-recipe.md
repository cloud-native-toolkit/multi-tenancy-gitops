# Deploy Cloud Pak for Business Automation - Process Mining capability

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-tools.yaml
    ```
### Services - Kustomization.yaml    
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/ibm-process-mining-operator.yaml
    - argocd/instances/ibm-process-mining-instance.yaml
    - argocd/operators/ibm-db2u-operator.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/operators/ibm-automation-foundation-core-operator.yaml
    - argocd/operators/ibm-catalogs.yaml
    ```
