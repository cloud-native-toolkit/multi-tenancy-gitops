# Deploy Cloud Pak for Integration - IBM API Connect capability

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-tools.yaml
    ```
### Services - Kustomization.yaml    
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/ibm-apic-operator.yaml
    - argocd/instances/ibm-apic-instance.yaml
    - argocd/operators/ibm-datapower-operator.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/operators/ibm-catalogs.yaml
    - argocd/instances/sealed-secrets.yaml
    ```
### Storage - ibm-apic-instance.yaml
1. Make sure the `storageClassName` specified in `${GITOPS_PROFILE}/2-services/argocd/instances/ibm-apic-instance.yaml`, which defaults to the **`ibm-block-gold`**, corresponds to an available **block** storage class in the cluster you are executing this recipe in.