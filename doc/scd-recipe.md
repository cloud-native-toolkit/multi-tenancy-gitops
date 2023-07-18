# Deploy IBM Sterling Connect Direct C:D

This recipe is for deploying the IBM Sterling Connect Direct (SC:D) in the `scd` namespace. This recipe also assumes you've already deployed the [Sterling File Gateway recipe](sfg-recipe.md) - either `b2bi-nonprod` and `b2bi-prod`, or both. 

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
    - argocd/namespace-connect-direct.yaml
    - argocd/serviceaccounts-connect-direct.yaml
    - argocd/sterling-cd-clusterwide.yaml
    ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` 

### Services - instances folder (in **multi-tenancy-gitops-services** repository)
**NOTE:** This recipe can be implemented using a combination of storage classes. Not all combination will work, but the following table lists the storage classes that have been tested successfully:

    | Component | Access Mode | IBM Cloud | OCS/ODF |
    | --- | --- | --- | --- |
    | PVC | RWO | ibmc-file-gold-gid | ocs-storagecluster-cephfs |

1. Clone the services repo for GitOps: open a terminal window and clone the `multi-tenancy-gitops-services` repository under your Git Organization.
        
    ```bash
    git clone git@github.com:${GIT_ORG}/multi-tenancy-gitops-services.git
    ```
### Services - kustomization.yaml (in **multi-tenancy-gitops** repository)
1. Deploy all pre-requisite resources for C:D in the main `multi-tenancy-gitops` repository

    1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following lines to install the pre-requisites for SCCM.
        ```yaml
        ## Connect Direct
        - argocd/instances/ibm-connect-direct-setup.yaml
        ```
    1. Deploy Connect Direct
        ```yaml
        - argocd/instances/ibm-connect-direct.yaml
        ```

    >  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` and
    > **Refresh** the ArgoCD application `services`.

---

### Validation

1.  Access `cd-63-ibm-connect-direct-0` pod Terminal.
    ```bash
    cd /opt/cdunix/ndm/bin
    ```
    Then 
    ```bash
    ./direct
    ```
1. OUTPUT
    ```
            **************************************************************
            *                                                            *
            *            Licensed Materials - Property of IBM            *
            *                                                            *
            *         IBM(R) Connect:Direct(R) for UNIX 6.3.0.0          *
            *                   Build date: 12May2023                    *
            *                                                            *
            *  (C) Copyright IBM Corp. 1992, 2023 All Rights Reserved.   *
            *                                                            *
            **************************************************************

    Enter a ';' at the end of a command to submit it. Type 'quit;' to exit CLI.

    Direct> 
    ```

