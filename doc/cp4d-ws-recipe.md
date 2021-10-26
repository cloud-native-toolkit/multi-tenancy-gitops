# Deploy Cloud Pak for Data - Watson Studio

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-tools.yaml
    - argocd/serviceaccounts-tools.yaml
    ```
### Services - Kustomization.yaml
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/ibm-cp4d-watson-studio-operator.yaml
    - argocd/instances/ibm-cp4d-watson-studio-instance.yaml
    - argocd/operators/ibm-cpd-platform-operator.yaml
    - argocd/operators/ibm-cpd-scheduling-operator.yaml
    - argocd/instances/ibm-cpd-instance.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/instances/ibm-foundational-services-instance.yaml
    - argocd/operators/ibm-catalogs.yaml
    - argocd/instances/sealed-secrets.yaml
    ```

### Validation
1. Get the status of the control plane (lite-cr)
    ```
    oc get ZenService lite-cr -n tools -o jsonpath="{.status.zenStatus}{'\n'}"
    ```

    Cloud Pak for Data control plane is ready when the command returns `Completed`. If the command returns another status, wait for some more time and rerun the command.

1. Get the status of Watson Studio (ws-cr)
    ```
    oc get WS ws-cr -n tools -o jsonpath="{.status.wsStatus} {'\n'}"
    ```

    Watson Studio is ready when the command returns `Completed`.

1. Get the URL of the Cloud Pak for Data web client and open it in a browser.
    ```
    echo https://`oc get ZenService lite-cr -n tools -o jsonpath="{.status.url}{'\n'}"`
    ```

1. The credentials for logging into the Cloud Pak for Data web client are `admin/<password>` where password is stored in a secret.
    ```
    oc extract secret/admin-user-details -n tools --keys=initial_admin_password --to=-
    ```
