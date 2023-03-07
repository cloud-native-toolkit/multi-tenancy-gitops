# Deploy [Business Automation Workflow](https://www.ibm.com/products/business-automation-workflow?lnk=flatitem)

This recipe is for deploying the the **STARTER** deployment of Business Automation Workflow assuming you reserved a [GitOps Cluster](https://techzone.ibm.com/my/reservations/create/60e8aefaec55c60018933dd0).



### Multi-tenancy-gitops-services - Kustomization.yaml 
1. Edit the kustomization file `multi-tenancy-gitops-services/operators/ibm-cp4ba-operator/kustomization.yaml`, and un-comment, comment, commit, and push the following changes:

```yaml
resources:
#- deployment/cp4ba-catalogsource.yaml      # comment this out
#- deployment/cp4ba-subscription.yaml       # comment this out

### BAW DEPLOYMENT ###
- deployment/cp4ba-baw-catalogsource.yaml
- deployment/cp4ba-baw-subscription.yaml
```


### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`, un-comment the following lines, commit and push the changes. Then refresh the `infra` Application in the ArgoCD console.

```yaml
- argocd/consolenotification.yaml
- argocd/namespace-tools.yaml
- argocd/namespace-ibm-common-services.yaml
- argocd/namespace-cp4ba.yaml
- argocd/serviceaccounts-baw.yaml
- argocd/machine-configuration.yaml
```

>  💡 **NOTE**  
>  *** make sure to `add`, `commit` & `push` the changes into git. ***



### Services - Kustomization.yaml
1. Add IBM ENTITLEMENT KEY on `cp4ba & ibm-common-services` namespaces using the terminal. 

>  💡 **NOTE**  
>  *** make sure you are logged into your cluster in your terminal and you change <ENTITLEMENT-KEY>. ***

```yaml
oc create secret docker-registry ibm-entitlement-key -n cp4ba \
--docker-username=cp \
--docker-password=<ENTITLEMENT-KEY> \
--docker-server=cp.icr.io
```

```yaml
oc create secret docker-registry ibm-entitlement-key -n ibm-common-services \
--docker-username=cp \
--docker-password=<ENTITLEMENT-KEY> \
--docker-server=cp.icr.io
```

2. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install CP4BA operator and BAW instance by uncommenting the following lines:
   
    ```yaml
    ## IBM CP4BA operator
    - argocd/operators/ibm-cp4ba-operator.yaml
    ```
    >  💡 **NOTE**  
    >  *** make sure to `add`, `commit` & `push` these changes to git. Then make sure it has finished deploying in argocd console before un-commenting the next step. ***

    ```yaml
    - argocd/instances/ibm-cp4ba-baw.yaml
    ```
  >  💡 **NOTE**  
  > *** make sure to `add`, `commit` & `push` the changes into git. The overall process took around 2.5 hours ***


### Validation
1.  Verify the status:
    ```bash
    oc get icp4acluster icp4adeploy -n cp4ba -o jsonpath="{.status}{'\n'}" | jq
    ```
