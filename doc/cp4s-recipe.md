# Deploy Cloud Pak for Security

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-tools.yaml
    ```
### Services - Kustomization.yaml
1. Edit the **CP4SThreatManagement**s custom resource instance and specify a block or file storage class `${GITOPS_PROFILE}/2-services/argocd/instances/ibm-cp4sthreatmanagements-instance.yaml`.  The default is set to `managed-nfs-storage`.
    ```yaml
      - name: spec.basicDeploymentConfiguration.storageClass
        value: managed-nfs-storage
      - name: spec.extendedDeploymentConfiguration.backupStorageClass
        value: managed-nfs-storage
    ```

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/ibm-cp4s-operator.yaml
    - argocd/instances/ibm-cp4sthreatmanagements-instance.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/instances/ibm-foundational-services-instance.yaml
    - argocd/operators/ibm-automation-foundation-core-operator.yaml
    - argocd/operators/ibm-catalogs.yaml
    ```

### Validation
1.  Check the status of the `CommonService` and `PlatformNavigator` custom resource.
    ```bash
    oc get CP4SThreatManagement threatmgmt -n tools -o jsonpath='{.status.conditions}'
    # Expected output = Cloudpak for Security Deployment is successful
    ```

1.  Before users can log in to the console for Cloud Pak for Security, an identity provider must be configured.  The [documentation](https://www.ibm.com/docs/en/cloud-paks/cp-security/1.8?topic=postinstallation-configuring-identity-providers) provides further instructions.  For **DEMO** purposes, OpenLDAP can be deployed and instructions are provided below.

1. Download the **cpctl** utility
    1. Log in to the OpenShift cluster
    ```bash
    oc login --token=<token> --server=<openshift_url> -n <namespace>
    ```
    1. Retrieve the pod that contains the utility
    ```bash
    POD=$(oc get pod --no-headers -lrun=cp-serviceability | cut -d' ' -f1)
    ```
    1. Copy the utility locally
    ```bash
    oc cp $POD:/opt/bin/<operatingsystem>/cpctl ./cpctl && chmod +x ./cpctl
    ```
1. Install OpenLDAP
    1. Start a session
    ```bash
    ./cpctl load
    ```
    1. Install OpenLDAP
    ```bash
    cpctl tools deploy_openldap --token $(oc whoami -t) --ldap_usernames 'adminUser,user1,user2,user3' --ldap_password cloudpak
    ```
1. Initial user log in
    1. Retrieve Cloud Pak for Security Console URL
    ```bash
    oc get route isc-route-default --no-headers -n <CP4S_NAMESPACE> | awk '{print $2}'
    ```
    1. Log in with the user ID and password specified (ie. `adminUser` / `cloudpak`).