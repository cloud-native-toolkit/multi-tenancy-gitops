# Deploy Cloud Pak for Integration - MQ capability

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-ci.yaml
    - argocd/namespace-dev.yaml
    - argocd/namespace-staging.yaml
    - argocd/namespace-prod.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-tools.yaml
    ```
### Services - Kustomization.yaml    
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/ibm-mq-operator.yaml
    - argocd/operators/ibm-platform-navigator.yaml
    - argocd/instances/ibm-platform-navigator-instance.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/instances/ibm-foundational-services-instance.yaml
    - argocd/operators/ibm-automation-foundation-core-operator.yaml
    - argocd/operators/ibm-catalogs.yaml
    - argocd/instances/sealed-secrets.yaml
    ```
1. Edit the Platform Navigator instance and specify a storage class that supports  ReadWriteMany (RWX) `${GITOPS_PROFILE}/2-services/argocd/instances/ibm-platform-navigator-instance.yaml`
    ```yaml
    storage:
        class: managed-nfs-storage
    ```
