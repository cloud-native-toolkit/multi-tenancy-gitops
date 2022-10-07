# Deploy [DataPower Gateway](https://www.ibm.com/products/datapower-gateway)

This recipe is for deploying the DataPower Gateway in a single namespace (i.e. `tools`): 

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console.

    ```bash        
    cd multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra
    ```

    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-tools.yaml
    - argocd/serviceaccounts-ibm-common-services.yaml
    - argocd/serviceaccounts-tools.yaml
    ```
    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` & go to ArgoCD, open `infra` application and click refresh.
    > Wait until everything gets deployed before moving to the next steps.

### Services - Kustomization.yaml

1. This recipe is can be implemented using a combination of storage classes. Not all combination will work, the following table lists the storage classes that we have tested to work:

    | Component | Access Mode | IBM Cloud | OCS/ODF |
    | --- | --- | --- | --- |
    | Platform Navigator | RWX | managed-nfs-storage | ocs-storagecluster-cephfs |

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Sealed Secrets by uncommenting the following line, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console.
   
    ```yaml
    ## IBM Foundational Services / Common Services
    - argocd/operators/ibm-foundations.yaml
    - argocd/instances/ibm-foundational-services-instance.yaml
    - argocd/operators/ibm-automation-foundation-core-operator.yaml

    ## IBM Catalogs
    - argocd/operators/ibm-catalogs.yaml

    # Sealed Secrets
    - argocd/instances/sealed-secrets.yaml
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` & go to ArgoCD, open `services` application and click refresh.
    > Wait until everything gets deployed before moving to the next steps.

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Sealed Secrets by uncommenting the following line, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console.
 
> **⚠️** Warning:
>> Make sure that `${GITOPS_PROFILE}/2-services/argocd/instances/ibm-platform-navigator-instance.yaml`
   
```yaml
    storage:
      class: managed-nfs-storage
```  
Then enable Platform Navigator Operator & Instance.  
```yaml
    ## Cloud Pak for Integration
    - argocd/operators/ibm-platform-navigator.yaml
    - argocd/instances/ibm-platform-navigator-instance.yaml
``` 

>  💡 **NOTE**  
> Commit and Push the changes for `multi-tenancy-gitops` & go to ArgoCD, open `services` application and click refresh.
> Wait until everything gets deployed before moving to the next steps.

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following line to install Sterling File Gateway, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console:

    ```yaml
    ## Cloud Pak for Integration
    - argocd/operators/ibm-datapower-operator.yaml
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` and
    > sync ArgoCD application `services` layer.

---

### Validation
1.  Check the status of the `CommonService`,`PlatformNavigator` & `Datapower` custom resource.
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

1. Validate Datapower Operator
    ```bash
    oc get operators datapower-operator.openshift-operators -o=jsonpath='{ .status.components.refs[12].conditions[*].type}'
    # Expected output = Succeeded
    ```  
    or from the console by doing the following steps
    ```bash
    oc console
    ``` 
    Click on `Operators Tab`->`Installed operators` from the menu on the left and validate the status of datapower operator `Succeeded`
    ![DataPower Operator](images/datapower-operator.png)
