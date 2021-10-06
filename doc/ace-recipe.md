# Deploy Cloud Pak for Integration - ACE capability

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
1. Edit the Platform Navigator instance and specify a storage class that supports ReadWriteMany (RWX) `${GITOPS_PROFILE}/2-services/argocd/instances/ibm-platform-navigator-instance.yaml`.  The default is set to `managed-nfs-storage`.
    ```yaml
    storage:
        class: managed-nfs-storage
    ```

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/ibm-ace-operator.yaml
    - argocd/operators/ibm-platform-navigator.yaml
    - argocd/instances/ibm-platform-navigator-instance.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/instances/ibm-foundational-services-instance.yaml
    - argocd/operators/ibm-automation-foundation-core-operator.yaml
    - argocd/operators/ibm-catalogs.yaml
    - argocd/instances/sealed-secrets.yaml
    ```

### Validation
1.  Check the status of the `CommonService` and `PlatformNavigator` custom resource.
    ```bash
    # Verify the Common Services instance has been deployed successfully
    oc get commonservice common-service -n ibm-common-services -o=jsonpath='{.status.phase}'
    # Expected output = Succeeded

    # [Optional] If selected, verify the Platform Navigator instance has been deployed successfully
    oc get platformnavigator -n tools -o=jsonpath='{ .items[*].status.conditions[].status }'
    # Expected output = True
    ```
1.  Log in to the Platform Navigator console
    ```bash
    # Retrieve Platform Navigator Console URL
    oc get route -n tools integration-navigator-pn -o template --template='https://{{.spec.host}}'
    # Retrieve admin password
    oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_username,admin_password --to=-
    ```
