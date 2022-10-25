# Deploy [Operational Decision Manager](https://www.ibm.com/products/operational-decision-manager)

### Obtain an OpenShift cluster
This document does not cover all of the intricacies of OpenShift installation or any of the requirements for the Cloud Pak for Business Automation; that stuff is all documented! This documentation is written with the assumption that you have provisioned a ROKS (Classic Infrastructure) cluster from Techzone. I typically use `16x64` & `5` nodes, depending on how many components you plan to install. I did not provision NFS storage; I will be using the IBM-provided storage classes. 

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console.

```bash        
    cd multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra
```

```yaml
- argocd/consolelink.yaml
- argocd/consolenotification.yaml
- argocd/namespace-ibm-common-services.yaml
- argocd/namespace-sealed-secrets.yaml
- argocd/namespace-tools.yaml
- argocd/namespace-db2.yaml
- argocd/namespace-cp4a.yaml
- argocd/namespace-odm.yaml
- argocd/namespace-openldap.yaml
- argocd/namespace-kube-system.yaml
```
    
>  💡 **NOTE**  
> Commit and Push the changes for `multi-tenancy-gitops` & go to ArgoCD, open `infra` application and click refresh.
 >> Wait until everything gets deployed before moving to the next steps.

### Adding a global pull secret using your [IBM Entitlement Key](https://myibm.ibm.com/products-services/containerlibrary) Cluster wide.
    
```bash
    export IBM_ENTITLEMENT_KEY=<IBM.ENTITELMENT.KEY>
```
```bash
    oc create secret docker-registry cpregistrysecret -n kube-system \
    --docker-server=cp.icr.io/cp/cpd \
    --docker-username=cp \
    --docker-password=${IBM_ENTITLEMENT_KEY} 
```
```bash
    oc create secret docker-registry ibm-entitlement-key -n ibm-common-services \
    --docker-server=cp.icr.io \
    --docker-username=cp \
    --docker-password=${IBM_ENTITLEMENT_KEY}
```
```bash
    oc create secret docker-registry ibm-entitlement-key -n db2 \
    --docker-server=cp.icr.io \
    --docker-username=cp \
    --docker-password=${IBM_ENTITLEMENT_KEY}
```
```bash
    oc create secret docker-registry ibm-entitlement-key -n cp4a \
    --docker-server=cp.icr.io \
    --docker-username=cp \
    --docker-password=${IBM_ENTITLEMENT_KEY}
```
### Adding `adding norootsquash`
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console.

```bash        
    cd multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra
```
```yaml
- argocd/norootsquash.yaml
```
### Services - Kustomization.yaml

1. This recipe is can be implemented using a combination of storage classes. Not all combination will work, the following table lists the storage classes that we have tested to work:

    | Component | Access Mode | IBM Cloud | OCS/ODF |
    | --- | --- | --- | --- |
    | DB2 | RWX | ibmc-file-gold-gid | ocs-storagecluster-cephfs |
    | ODM | RWX | ibmc-file-gold-gid | ocs-storagecluster-cephfs |

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install db2 operator, db2 instance, openldap & CP4A operator  by uncommenting the following line, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console.
   
    ```yaml
    ## IBM DB2 operator & instance, Ldap
    - argocd/operators/ibm-cp4a-db2.yaml
    - argocd/instances/ibm-cp4a-db2ucluster.yaml
    - argocd/instances/ibm-cp4a-openldap-odm.yaml
    ## IBM CP4A operator
    - argocd/operators/ibm-cp4a-odm-operator.yaml
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` & go to ArgoCD, open `services` application and click refresh.
    > Wait until everything gets deployed before moving to the next steps.


### Create database users
#### Log into the LDAP pod

To run these commands you will need to log in to the LDAP pods. From now on this document will refer to this as the LDAP pod.

1. Open up a new terminal or shell.
First we need to get the name of the pod: 
    ```bash
    oc project db2
    ldap_pod=$(oc get pods -l role=ldap -o name)
    ```
1. Log in to the Db2 pod:
    ```bash
    oc rsh ${ldap_pod} /bin/bash
    ```
1. Create database user for Business Automation Navigator:
    ```bash
    /opt/ibm/ldap_scripts/addLdapUser.py -u icnadm -p Passw0rd -r user
    ```
1. Create database user for Operational Decision Manager:
    ```bash
    /opt/ibm/ldap_scripts/addLdapUser.py -u odmadm -p Passw0rd -r user
    ```
    >  💡 **NOTE**  
    > Once your users are created you can type `exit` to exit the pod.

### Configuring the database
1. Create the databases
To run these commands you will need to log in to one of the Db2 pods. From now on this document will refer to this as the Db2 pod.
    ```
    oc project db2
    oc get pods
    ```
1. It will return something like this:
    ```c
    NAME                                        READY   STATUS      RESTARTS   AGE
    c-db2ucluster-cp4ba-db2u-0                  1/1     Running     0          39m
    c-db2ucluster-cp4ba-etcd-0                  1/1     Running     0          39m
    c-db2ucluster-cp4ba-instdb-fccgh            0/1     Completed   0          42m
    c-db2ucluster-cp4ba-ldap-688dd46d48-tdjrr   1/1     Running     0          42m
    c-db2ucluster-cp4ba-restore-morph-8tpff     0/1     Completed   0          38m
    db2u-operator-manager-5bf49db4ff-7fr4n      1/1     Running     0          93m
    ```
1. Access the pod which ends with `db2u-0`:
    ```bash
    oc rsh c-db2ucluster-cp4ba-db2u-0/bin/bash
    ```
1. Once inside the pod you need to switch to the user that is the instance owner (probably db2inst1).
    ```bash
    sudo su - ${DB2INSTANCE}
    ```
1. You will run the commands in this section from inside this Db2 pod.
for `Business Automation Navigator`, Create the database:
    ```bash
    db2 create database icndb automatic storage yes using codeset UTF-8 territory US pagesize 32768;
    ```
    >  💡 **NOTE**  
    > This will probably will take from `5-10` and then it should return this: 
    > `DB20000I  The CREATE DATABASE command completed successfully.`
1. Add user permissions:
    ```bash
    db2 connect to icndb;
    db2 grant dbadm on database to user icnadm;
    db2 connect reset;
    ```
### Operational Decision Manager database configuration:
1. Create the database:
    ```bash
    db2 create database odmdb automatic storage yes using codeset UTF-8 territory US pagesize 32768;
    ```
    >  💡 **NOTE**  
    > This will probably will take from `5-10` and then it should return this: 
    > `DB20000I  The CREATE DATABASE command completed successfully.`
1. Add user permissions:
    ```c
    db2 connect to odmdb;
    db2 CREATE BUFFERPOOL BP32K SIZE 2000 PAGESIZE 32K;
    db2 CREATE TABLESPACE RESDWTS PAGESIZE 32K BUFFERPOOL BP32K;
    db2 CREATE SYSTEM TEMPORARY TABLESPACE RESDWTMPTS PAGESIZE 32K BUFFERPOOL BP32K;
    db2 grant dbadm on database to user odmadm;
    db2 connect reset;
    ```
### Deploy ODM Operational Decision Manager
1. Validate database connectivity for Business Automation Navigator:
    ```bash
    db2 connect to icndb user icnadm using Passw0rd;
    db2 connect reset;
    ```
    >  💡 **NOTE**  
    > This should return this: 
    ```bash
       Database Connection Information

    Database server        = DB2/LINUXX8664 11.5.7.0
    SQL authorization ID   = ICNADM
    Local database alias   = ICNDB
    ```
1. Validate database connectivity for Operational Decision Manager:
    ```bash
    db2 connect to odmdb user odmadm using Passw0rd;
    db2 connect reset;
    ```
    >  💡 **NOTE**  
    > This should return this: 
    ```bash
        Database Connection Information

    Database server        = DB2/LINUXX8664 11.5.7.0
    SQL authorization ID   = ODMADM
    Local database alias   = ODMDB
    ```
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Sealed Secrets by uncommenting the following line, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console.
 
    ```yaml
    - argocd/instances/ibm-cp4a-icp4acluster.yaml
    ```
>  💡 **NOTE**  
> Commit and Push the changes for `multi-tenancy-gitops` & go to ArgoCD, open `services` application and click refresh.
> Wait until everything gets deployed before moving to the next steps.


> **⚠️** Warning:
>> Make sure that may take between `1.5 hrs to 2 hrs`

---

### Validation
1.  Verify the status:
    ```bash
    oc get icp4acluster icp4adeploy -n cp4ba -o jsonpath="{.status}{'\n'}" | jq
    ```
1. Access The URLs can be found in the `icp4adploy-cp4a-access-info` configmap in the `cp4a` namespace. Look for the section called `odm-access-info`, which will contain content similar to this:
    ```yaml
    CloudPak dashboard: https://cpd-$NAMESPACE.$INGRESS_DOMAIN
    ODM Decision Center URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/decisioncenter
    ODM Decision Runner URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/DecisionRunner
    ODM Decision Server Console URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/res
    ODM Decision Server Runtime URL: https://cpd-$NAMESPACE.$INGRESS_DOMAIN/odm/DecisionService
    ```

1. When the cloud pak is successfully installed you should be able to login as the default admin user. In this case, the default admin user is `admin` and the `password` can be found in the `ibm-iam-bindinfo-platform-auth-idp-credentials` secret in the `cp4a` namespace. 

### Post Deployment Steps
#### Deploy console links
You will need to run `console.sh` script to be able to access ODM console links:
```bash
cd multi-tenancy-gitops-services/instances/ibm-icpacluster/post-deploy
```
```bash
chmod +x ./console.sh
```
- Define your desired `namespace` must be the same as where the operator got deployed in this example we are using cp4a
```bash
export NAMESPACE=cp4a
```
```bash
./console.sh
```
#### Granting users.
You will need to grant your users various access roles, depending on their needs. You manage permissions using the `Administration` -> `Access control page` in the `Cloud pak dashboard`.

1. Click on the hamburger menu on the top left corner of the dashboard; expand the `Administration` section and click on `Access control`.

1. Click on the User Groups tab, then click on `New user group`.

1. Name the group `odmadmins`, and click `Next`.

1. Click `Identity provider groups`, then type cpadmins in the search field. It should come back with one result: `cn=cpadmins,ou=Groups,dc=cp`. Select it and click `Next`. Click all of the `roles`:
    ```
    Administrator
    Automation Administrator
    Automation Analyst
    Automation Developer
    Automation Operator
    ODM Administrator
    ODM Business User
    ODM Runtime administrator
    ODM Runtime user
    User
    ```
Click `Next`, then click `Create`.
