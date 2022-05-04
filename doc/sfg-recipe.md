# Deploy [Sterling File Gateway](https://developer.ibm.com/components/sterling/tutorials/)


### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console.

    ```bash        
    cd multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra
    ```

    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-b2bi-prod.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/serviceaccounts-b2bi-prod.yaml
    - argocd/sfg-b2bi-clusterwide.yaml
    ```

### Services - Kustomization.yaml

1. This recipe is currently set to use the `ibmc-file-gold` storageclass provided by IBM Cloud by default. If you need to use a different storageclass for `ReadWriteMany` access mode - set the environment variable `RWX_STORAGECLASS`.

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Sealed Secrets by uncommenting the following line, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console.
    ```yaml
    - argocd/instances/sealed-secrets.yaml

    ```
1. Generate Sealed Secrets resources required by Sterling File Gateway. 

    1. Open a terminal window and clone the `multi-tenancy-gitops-services` repository under your Git Organization.
        
        ```bash
        git clone git@github.com:${GIT_ORG}/multi-tenancy-gitops-services.git
        ```
        ```bash
        cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi-setup
        ```
    1. Generate a Sealed Secret for the credentials.
        ```bash
        NS=b2bi-prod \
        B2B_DB_SECRET=db2inst1 \
        JMS_PASSWORD=password JMS_KEYSTORE_PASSWORD=password JMS_TRUSTSTORE_PASSWORD=password \
        B2B_SYSTEM_PASSPHRASE_SECRET=password \
        ./sfg-b2bi-secrets.sh
        ```

1. Generate Persistent Volume Yamls required by Sterling File Gateway:
    ```bash
    RWX_STORAGECLASS=ocs-storagecluster-cephfs ./sfg-b2bi-pvc-mods.sh
    ```

    >  💡 **NOTE**  
    > Push the changes & sync ArgoCD.

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following lines to install the pre-requisites for Sterling File Gateway, **commit** and **push** the changes and synchronize the `services` Application in the ArgoCD console.
    ```yaml
    - argocd/instances/ibm-sfg-db2-prod.yaml
    - argocd/instances/ibm-sfg-mq-prod.yaml
    - argocd/instances/ibm-sfg-b2bi-prod-setup.yaml
    ```

    >  💡 **NOTE**  
    > Push the changes & sync ArgoCD. 

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following line to install Sterling File Gateway, commit and push the changes and synchronize the `services` Application in the ArgoCD console:
   
1. Generate Helm Chart values.yaml for the Sterling File Gateway Helm Chart:
    ```
    cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi-prod
    ./ibm-sfg-b2bi-overrides-values.sh
    ```
    >  💡 **NOTE**  
    > Push the changes & sync ArgoCD

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following line to install Sterling File Gateway, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console:

    ```yaml
    - argocd/instances/ibm-sfg-b2bi-prod.yaml
    ```

    >  💡 **NOTE**  
    > Push the changes & sync ArgoCD this will take around 1.5 hr.
---
> **⚠️** Warning:  
> If you decided to scale the pods or upgrade the verison you should do the following steps:
>> **This is to avoid going through the job again**

- Step 1:
    ```bash
    cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi
    ```
- Step 2:
  - Inside `values.yaml`, find & set 
  - ```bash
    datasetup:
        enable: false
    dbCreateSchema: false
    ```

### Validation

1.  Retrieve the Sterling File Gateway console URL.

    ```bash
    oc get route -n tools ibm-sfg-b2bi-sfg-asi-internal-route-dashboard -o template --template='https://{{.spec.host}}'
    ```

2. Log in with the default credentials:  username:`fg_sysadmin` password: `password` 
