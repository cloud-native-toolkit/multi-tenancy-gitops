# Deploy IBM Sterling Partner Engagement Manager

This recipe is for deploying the B2BI Sterling Partner Engagement Manager in a single namespace (i.e. `pem`). This recipe requires you to activate the [Sterling File Gateway recipe](sfg-recipe.md) on two namespaces, namely `b2bi-nonprod` and `b2bi-prod`. 
This guide assumes that you already deploys and verifies the 2 instances of the Sterling File Gateway.

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console. (Note that existing modules that are required for Sterling File Gateway should not be commented out)

    ```bash        
    cd multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra
    ```

    ```yaml
    - argocd/namespace-pem.yaml
    - argocd/serviceaccounts-pem.yaml
    - argocd/pem-b2bi-clusterwide.yaml
    - argocd/daemonset-sync-global-pullsecret.yaml

    ```

### Services - Kustomization.yaml

1. This recipe is can be implemented using a combination of storage classes. Not all combination will work, the following table lists the storage classes that we have tested to work:

    | Component | Access Mode | IBM Cloud | OCS/ODF |
    | --- | --- | --- | --- |
    | DB2 | RWO | ibmc-block-gold | ocs-storagecluster-cephfs |
    | PEM | RWX | managed-nfs-storage | ocs-storagecluster-cephfs |

1. Clone the services repo for GitOps: open a terminal window and clone the `multi-tenancy-gitops-services` repository under your Git Organization.
        
    ```bash
    git clone git@github.com:${GIT_ORG}/multi-tenancy-gitops-services.git
    ```

2. Modify the PEM pre-requisites components which includes the secrets and PVCs required for the B2BI helm chart.

    1. Go to the `instances/ibm-pem-setup` directory:

        ```bash
        cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi-prod-setup
        ```

    1. Generate the pre-reqs for PEM: 
        ```bash
        PEM_DB_PASSWORD=db2inst1 \
        PEM_PASSWORD=password \
        SERVER_KEYSTORE_PASSWORD=password \
        B2BI_PROD_PASSWORD=password \
        B2BI_PROD_DB_PASSWORD=db2inst1 \
        B2BI_NONPROD_PASSWORD=password \
        B2BI_NONPROD_DB_PASSWORD=db2inst1 \
        RWX_STORAGECLASS=managed-nfs-storage \
        ./pem-prereqs.sh
        ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops-services` 

1. Enable DB2 and prerequisites in the main `multi-tenancy-gitops` repository

    1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following lines to install the pre-requisites for Sterling File Gateway.
        ```yaml
        - argocd/instances/ibm-pem-db2.yaml
        - argocd/instances/ibm-pem-db2test.yaml
        - argocd/instances/ibm-pem-setup.yaml
        ```

    1. **Optional** Modify the DB2 storage classes to the environment that you use, the files are in `${GITOPS_PROFILE}/2-services/argocd/instances`. Edit `ibm-pem-db2.yaml` and `ibm-pem-db2test.yaml` to switch the storageClassName if necessary.


    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` and
    > **Refresh**  the ArgoCD application `services`.
    >
    > Make sure that the sterling toolkit pod does not throw any error.
    > Wait for 5-10 minutes until the database is fully initialized. 
   
1. Generate Helm Chart values.yaml for the Partner Engagement Manager Helm Chart in the `multi-tenancy-gitops-services` repo; note that the default storage class is using `managed-nfs-storage` - if you are installing on ODF, set `RWX_STORAGECLASS=ocs-storagecluster-cephfs`.

    ```
    cd multi-tenancy-gitops-services/instances/ibm-pem
    ./ibm-pem-overrides-values.sh
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops-services` 

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following line to install Sterling File Gateway, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console:

    ```yaml
    - argocd/instances/ibm-pem.yaml
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` and
    > sync ArgoCD application `services` this will take around 1 hr for the database setup.
    > If the migrator shows SQLCODE 57019 - that means PEM is started to early - comment out the line and wait a couple of minutes before re-enabling the `ibm-pem.yaml`.

---

> **⚠️** Warning:  
> If you decided to scale the pods or upgrade the verison you should do the following steps:
>> **This is to avoid going through the database setup job again**

- Step 1:
    ```bash
    cd multi-tenancy-gitops-services/instances/ibm-pem
    ```
- Step 2:
  - Inside `values.yaml`, find & set 
  - ```bash
    dbsetup:
        enable: false
        upgrade: true
    ```
- Commit and push the changes for the `multi-tenancy-gitops-services` repo.
---

### Validation

1.  Retrieve the Partner Engagement Manager and Community Managers console URL.

    ```bash
    oc get route -n pem ibm-pem-pem-route  -o template --template='https://{{.spec.host}}'
    oc get route -n pem ibm-pem-prodpem-route  -o template --template='https://{{.spec.host}}'
    oc get route -n pem ibm-pem-nonprodpem-route  -o template --template='https://{{.spec.host}}'
    ```

2. Log in to Partner Engagement Manager with the default credentials:  username:`admin` password: `password` 

2. Log in to Partner Engagement Manager Community Management URLs (Prod and Nonprod) with the default credentials:  username:`superadmin` password: `password` 

