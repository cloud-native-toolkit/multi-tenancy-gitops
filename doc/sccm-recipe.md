# Deploy IBM Sterling Control Center Monitor

This recipe is for deploying the IBM Sterling Control Center Monitor (SCCM) in the `sccm` namespace. This recipe also assumes you've already deployed the [Sterling File Gateway recipe](sfg-recipe.md) - either `b2bi-nonprod` and `b2bi-prod`, or both. 

In particular, these infra resources are assumed to have already been deployed (aside from the B2Bi specific resources):

```yaml
- argocd/namespace-sealed-secrets.yaml
- argocd/daemonset-sync-global-pullsecret.yaml
```

### Infrastructure - kustomization.yaml (in **multi-tenancy-gitops** repository)
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console.

    ```bash        
    cd multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra
    ```

    In, `kustomization.yaml`:

    ```yaml
    - argocd/namespace-sccm.yaml
    - argocd/serviceaccounts-sccm.yaml
    - argocd/sccm-clusterwide.yaml
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` 

### Services - instances folder (in **multi-tenancy-gitops-services** repository)
**NOTE:** This recipe can be implemented using a combination of storage classes. Not all combination will work, but the following table lists the storage classes that have been tested successfully:

    | Component | Access Mode | IBM Cloud | OCS/ODF |
    | --- | --- | --- | --- |
    | DB2 | RWO | ibmc-block-gold | ocs-storagecluster-cephfs |
    | PEM | RWX | managed-nfs-storage | ocs-storagecluster-cephfs |

1. Clone the services repo for GitOps: open a terminal window and clone the `multi-tenancy-gitops-services` repository under your Git Organization.
        
    ```bash
    git clone git@github.com:${GIT_ORG}/multi-tenancy-gitops-services.git
    ```

2. Generate the yaml files for the SCCM pre-requisite components which includes the secrets and PVCs required by the SCCM helm chart.<br/>
**NOTE:** Make sure you are logged into your OpenShift cluster before proceeding.

    1. Go to the `instances/ibm-sccm-setup` directory:

        ```bash
        cd multi-tenancy-gitops-services/instances/ibm-sccm-setup
        ```

    2. Generate the pre-requisite yaml files for SCCM (this includes keystore and truststore files using a self-signed certificate for demo purposes which is used by SCCM to secure connections with the SCCM engine, including between the web console and the browser; refer: https://www.ibm.com/docs/en/control-center/6.2.1.0?topic=securing-configuring-secure-connections): 

        ```bash
        CC_DB_PASSWORD=db2inst1 \
        ADMIN_USER_PASSWORD=password \
        JMS_PASSWORD=password \
        KEYSTORE_PASSWORD=password \
        TRUSTSTORE_PASSWORD=password \
        EMAIL_PASSWORD=password \
        USER_KEY=password \
        KEY_ALIAS=self \
        ./ibm-sccm-prereqs.sh
        ```

        As part of creating the self-signed certificate for the JKS files required by SCCM, you will be prompted for the following (respond as follows):
        ```
        Enter keystore password: password

        Trust this certificate? [no]: y
        ```

        If the script runs successfully, it will generate the following files:
        - ibm-sccm-input-pvc.yaml
        - ibm-sccm-keystore-jks.yaml
        - ibm-sccm-pvc.yaml
        - ibm-sccm-secret.yaml
  
    >  💡 **NOTE**  
    > Add the generated files to the repository, and
    > Commit and Push the changes for `multi-tenancy-gitops-services` 

### Services - kustomization.yaml (in **multi-tenancy-gitops** repository)
1. Deploy the DB2 and pre-requisite resources for SCCM in the main `multi-tenancy-gitops` repository

    1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following lines to install the pre-requisites for SCCM.
        ```yaml
        # SCCM
        - argocd/instances/ibm-sccm-db2.yaml
        - argocd/instances/ibm-sccm-setup.yaml
        ```

    2. **(Optional)** If necessary, modify the DB2 storage class for the environment that you use, the files are in `${GITOPS_PROFILE}/2-services/argocd/instances`. Edit `ibm-sccm-db2.yaml` to change the storageClassName if necessary.


    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` and
    > **Refresh** the ArgoCD application `services`.
    >
    > Make sure that the sterling toolkit pod does not throw any error.
    > Wait for 5-10 minutes until the database is fully initialized. 
    >
    > Push the changes & sync ArgoCD and make sure db2 database script completes successfully (check db2-0 pod Logs). 

### Services - instances folder (in **multi-tenancy-gitops-services** repository)

1. Generate values.yaml file for the SCCM Helm Chart in the `multi-tenancy-gitops-services` repo; note that the default storage class is using `managed-nfs-storage` - if you are installing on ODF, set `RWX_STORAGECLASS=ocs-storagecluster-cephfs`.:
    
    ```bash
    cd multi-tenancy-gitops-services/instances/ibm-sccm
    ```
    In order to deploy SCCM, SMTP settings are required which SCCM uses for sending emails triggered by system events based on business rules (refer: https://www.ibm.com/docs/en/control-center/6.2.1.0?topic=settings-configuring-smtp-email-messages).

    ```bash
    ADMIN_EMAIL_ADDRESS=<change_me> \
    EMAIL_HOST_NAME=<change_me> \
    EMAIL_PORT=<change_me> \
    EMAIL_USER=<change_me> \
    EMAIL_RESPOND=<change_me> \
    CC_ADMIN_EMAIL_ADDRESS=<change_me> \
    KEY_ALIAS=self \
    ./ibm-sccm-overrides-values.sh
    ```

    For example:

    ```bash
    ADMIN_EMAIL_ADDRESS=no.reply@gmail.com \
    EMAIL_HOST_NAME=smtp.gmail.com \
    EMAIL_PORT=465 \
    EMAIL_USER=no.reply@gmail.com \
    EMAIL_RESPOND=no.reply@gmail.com \
    CC_ADMIN_EMAIL_ADDRESS=no.reply@gmail.com \
    KEY_ALIAS=self \
    ./ibm-sccm-overrides-values.sh
    ```

    >  💡 **NOTE**  
    > Add the generated values.yaml file to the repository, and
    > Commit and Push the changes for `multi-tenancy-gitops-services` 

### Services - kustomization.yaml (in **multi-tenancy-gitops** repository)

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following line to install SCCM, **commit** and **push** the changes and **Refresh** the `services` Application in the ArgoCD console:

    ```yaml
    # SCCM

   - argocd/instances/ibm-sccm.yaml
    ```
    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` and
    >  **Refresh** the ArgoCD application `services`. This will take around 10-15 mins including all the database setup and application startup. Make sure sccm pod starts successfully (check ibm-sccm-ibm-sccm-0 pod Logs indicate at the end -> ---Configuration Completed---).

---

### Services - instances folder (in **multi-tenancy-gitops-services** repository)

> **⚠️** Warning:  
> If you decided to scale the pods or upgrade the verison you should do the following steps:
>> **This is to prevent running the  setup job again**

- Step 1:
    ```bash
    cd multi-tenancy-gitops-services/instances/ibm-sccm
    ```
- Step 2:
  - Inside `values.yaml`, find & set 
  - ```bash
    dbInit: "false"
    ```
- Commit and push the changes for the `multi-tenancy-gitops-services` repo.
---

### Validation

1.  Retrieve the Sterling Control Center Monitor console URL.

    ```bash
    oc get route -n sccm ibm-sccm-ibm-sccm -o template --template='https://{{.spec.host}}'
    ```

2. Log in with the default credentials: User ID: `admin` Password: `password` 
>  💡 **NOTE**  
> Since we used a self-signed certificate, you may need to use a browser that allows connection to a site with a self-signed certificate such as Firefox
