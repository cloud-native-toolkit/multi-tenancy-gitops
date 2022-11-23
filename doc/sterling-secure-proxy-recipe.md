# Deploy [Sterling Secure Proxy](https://developer.ibm.com/components/sterling/tutorials/)

This recipe is for deploying Sterling Secure Proxy in a single namespace (i.e. `ssp`):

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console.

    ```bash        
    cd multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra
    ```

    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ssp.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/daemonset-sync-global-pullsecret.yaml
    ```

    >  💡 **NOTE** 
   > > There is currently a bug where IBM entitled images cannot be pulled on ROKS clusters without updating the global pull secret manually first, if this occurs then update your global pull secret and *RELOAD* your nodes.

### Services - Kustomization.yaml

1. This recipe only works with Read/Write Once memory as per the docs [here](https://www.ibm.com/docs/en/secure-proxy/6.0.3?topic=tasks-creating-storage-data-persistence)

Our example to use is ```ibmc-file-silver```

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Sealed Secrets by uncommenting the following line, **commit** and **push** the changes and refresh the `services` Application in the ArgoCD console.
    ```yaml
    - argocd/instances/sealed-secrets.yaml
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` & sync ArgoCD. 

2. Clone the services repo for GitOps, open a terminal window and clone the `multi-tenancy-gitops-services` repository under your Git Organization.
        
    ```bash
    git clone git@github.com:${GIT_ORG}/multi-tenancy-gitops-services.git
    ```

3. Create a file named ```ssp-env.sh``` to store your local variables, and then run ```source ./ssp-env.sh``` note: You might need to give it run permissions

    1. Example environment variables:
        ```
       export CM_SYS_PASS=mypasswOrd1!
       export CM_ADMIN_PASSWORD=mypasswOrd1!
       export CM_CERTSTORE_PASSWORD=mypasswOrd1!
       export CM_CERTENCRYPT_PASSWORD=mypasswOrd1!
       export CM_CUSTOMCERT_PASSWORD=mypasswOrd1!
       export ENGINE_SYS_PASS=mypasswOrd1!
       export ENGINE_CERTSTORE_PASSWORD=mypasswOrd1!
       export ENGINE_CERTENCRYPT_PASSWORD=mypasswOrd1!
       export ENGINE_CUSTOMCERT_PASSWORD=mypasswOrd1!
       export RWX_STORAGECLASS=ibmc-file-silver
       export NS=ssp
       ```
    2. Login to the openshift cluster and ensure that you are using the correct project ```ssp```
       1. ```oc project ssp```
    3. Move into the services repo, then instances, then sterling-secure-proxy-setup and run ```run-setup.sh```
       1. This will create your services accounts, pvcs, and secrets necessary for the setup.

    >  💡 **NOTE** 
   > > Commit and Push the changes for `multi-tenancy-gitops-services` 

4. Enable SSP and prerequisites in the main `multi-tenancy-gitops` repository

    1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following lines to install the pre-requisites for Sterling File Gateway.
        ```yaml
       - argocd/instances/sterling-secure-proxy-setup.yaml
       - argocd/instances/sterling-secure-proxy-hook.yaml
       - argocd/instances/sterling-secure-proxy-cm-instance.yaml
       - argocd/instances/sterling-secure-proxy-engine-instance.yaml
       ```

>  💡 **NOTE**
> 
> Commit and Push the changes for `multi-tenancy-gitops` and
> sync the ArgoCD application `services`.
>
> You can now view the pods spinning up in the SSP namespace.
> 
> You should see the cm spin up first and it will take 7-12 minutes to finish
>
> then the key-cert handoff will occur
>
> followed by the engine spinning up

### Validation


1.  Retrieve the Sterling File Gateway console URL.

    ```bash
    oc get route -n ssp ibm-ssp-cm-ibm-ssp-cm -o template --template='https://{{.spec.host}}'
    ```
    The default credentials to login are 
    ```bash
    admin
    mypasswOrd1!
    ```