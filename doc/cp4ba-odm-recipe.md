# Deploy [Operational Decision Manager](https://www.ibm.com/products/operational-decision-manager)

This recipe is for deploying the Operational Desision Manager in a single namespace. The typical size of the cluster is 5 worker nodes with 16CPU and 64GB RAM.  

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and refresh the `infra` Application in the ArgoCD console.

>  💡 **NOTE**  
>  - `norootsquash` is only needed if you are running on ROKS with ibmc-file-gold-gid PVCs
>  - `daemonset-sync-global-pullsecret` can work if you are working with a cluster from TechZone, otherwise you need to create the ibm-entitlement-key pull secrets on the `kube-system`, `ibm-common-services`, `db2` and `cp4ba` namespaces


```yaml
- argocd/consolenotification.yaml
- argocd/namespace-ibm-common-services.yaml
- argocd/namespace-db2.yaml
- argocd/namespace-cp4ba.yaml
- argocd/namespace-openldap.yaml
- argocd/norootsquash.yaml
- argocd/daemonset-sync-global-pullsecret.yaml
```
    

### Services - Kustomization.yaml

1. This recipe is can be implemented using a combination of storage classes. Not all combination will work, the following table lists the storage classes that we have tested to work:

    | Component | Access Mode | IBM Cloud | OCS/ODF |
    | --- | --- | --- | --- |
    | DB2 | RWX | ibmc-file-gold-gid | ocs-storagecluster-cephfs |
    | LDAP | RWX | ibmc-file-gold <br/> managed-nfs-storage | ocs-storagecluster-cephfs |
    | ODM | RWX | ibmc-file-gold-gid <br/> managed-nfs-storage | ocs-storagecluster-cephfs |
    | ODM | RWO | ibmc-block-gold <br/> managed-nfs-storage | ocs-storagecluster-ceph-rbd |

    Changing the storage classes are performed in the following files:
    - multi-tenancy-gitops-services/instances/ibm-cp4ba-icp4acluster/odm/odm-deploy.yaml
    - multi-tenancy-gitops-services/instances/ibm-cp4ba-db2ucluster/db2-instance/db2-instance.yaml
    - multi-tenancy-gitops-services/instances/ibm-cp4ba-openldap-odm/deployment/ldap-statefulset.yaml

1. These instructions are assuming that all the user created has the password of `Passw0rd`. changing this default can be performed in the following files:
    - multi-tenancy-gitops-services/instances/ibm-cp4ba-openldap-odm/configmaps/cm-customdif-stack-ha.yaml
    - multi-tenancy-gitops-services/instances/ibm-cp4ba-icp4acluster/odm/ibm-ban-secret.yaml
    - multi-tenancy-gitops-services/instances/ibm-cp4ba-db2u-setup/setup-script.yaml
    - multi-tenancy-gitops-services/instances/ibm-cp4ba-icp4acluster/odm/odm-db-secret.yaml

1. Modify the console link properties with the proper CloudPak for Business Automation link in the `multi-tenancy-gitops-services` repository, make sure that you are already **logged in** your cluster:

    ```bash
    cd multi-tenancy-gitops-services/instances/ibm-cp4ba-icp4acluster-postdeploy/post-deploy
    ```
    ```
    NAMESPACE=cp4ba ./console.sh
    ```
    >  💡 **NOTE**  
    >  ***You should see `5` changes, make sure to `add`, `commit` & `push` the changes into git.***

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install db2 operator, db2 instance, openldap & CP4BA operator  by uncommenting the following lines: 
   
    ```yaml
    ## IBM DB2 operator & instance, Ldap
    - argocd/operators/ibm-cp4ba-db2.yaml
    - argocd/instances/ibm-cp4ba-db2ucluster.yaml
    - argocd/instances/ibm-cp4ba-db2u-setup.yaml
    - argocd/instances/ibm-cp4ba-openldap-odm.yaml
    ## IBM CP4BA operator
    - argocd/operators/ibm-cp4ba-operator.yaml
    - argocd/instances/ibm-cp4ba-icp4acluster.yaml
    - argocd/instances/ibm-cp4ba-icp4acluster-postdeploy.yaml 
    ```
  >  💡 **NOTE**  
  > ***The overall process took around 2 hours***


### Validation
1.  Verify the status:
    ```bash
    oc get icp4acluster icp4adeploy -n cp4ba -o jsonpath="{.status}{'\n'}" | jq
    ```
1. Access The URLs can be found in the `icp4adploy-cp4ba-access-info` configmap in the `cp4ba` namespace. Look for the section called `odm-access-info`, which will contain content similar to this:
    ```yaml
    CloudPak dashboard: https://cpd-$NAMESPACE.$INGRESS_DOMAIN
    ODM Decision Center URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/decisioncenter
    ODM Decision Runner URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/DecisionRunner
    ODM Decision Server Console URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/res
    ODM Decision Server Runtime URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/DecisionService
    ```

1. Use the LDAP authentication with the userID of `cpadmin` and the password of `Passw0rd` (unless you changed this default).
