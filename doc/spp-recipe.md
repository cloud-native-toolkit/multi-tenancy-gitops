# Deploy IBM Spectrum Protect Plus 

This recipe is for deploing IBM Spectrum Protect Plus - there are two components that can be deployed independently, 

## IBM Spectrum Protect Plus server 

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-spp.yaml
    ```
### Services - Kustomization.yaml

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/instances/sealed-secrets.yaml
    - argocd/operators/spp-catalog.yaml
    ```

2. Commit and push the changes that you have made to Git to allow the sealed secret and spp-catalog to be available in GitOps.

3. Run the script to customize the `spp-instance.yaml`, this is a custom script to configure the Spectrum Protect Plus server components. 

    ``` bash
    IBM_ENTITLEMENT_KEY=<entitlement> SPPUSER=sppadmin SPPPW=passw0rd ./scripts/spp-instance.sh
    ```

4. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/spp-operator.yaml
    - argocd/instances/spp-instance.yaml
    ```

5. Commit and push your changes to Git

### Validation
1.  Login to the IBM Specrum Protect plus UI: 
    ```bash
    # Retrieve Platform Navigator Console URL
    oc get route -n spp sppproxy -o template --template='https://{{.spec.host}}'
    # Retrieve admin password
    oc extract -n spp secrets/sppadmin --keys=adminUser,adminPassword --to=-
    ```


## Container Backup Support (BaaS) component 

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-spp-velero.yaml
    - argocd/namespace-baas.yaml
    ```
### Services - Kustomization.yaml

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following (unless it has been uncommented):

    ```yaml
    - argocd/instances/sealed-secrets.yaml
    ```

2. Commit and push the changes that you have made to Git to allow the sealed secret and spp-catalog to be available in GitOps (note that if you also install SPP server component, these 2 steps are already done)

3. Run the script to customize the `baas-instance.yaml`, this is a custom script to configure the Container Backup Support component

    ``` bash
    IBM_ENTITLEMENT_KEY=<entitlement> SPPUSER=sppadmin SPPPW=passw0rd ADMINUSER=baasadmin ADMINPW=passw0rd SPPFQDN="ibmspp.apps.cluster.domain" ./scripts/baas-instance.sh
    ```

    **Note** `SPPFQDN` does not need to be specified if BaaS is installed on the same cluster as the SPP server component.

4. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:

    ```yaml
    - argocd/operators/oadp-operator.yaml
    - argocd/instances/oadp-instance.yaml
    - argocd/operators/baas-operator.yaml
    - argocd/instances/baas-instance.yaml
    ```

5. Commit and push your changes to Git

### Validation
1.  Run the following command to check the pods deployed, the last one will be the set of pods for `baas-transaction-manager`:

    ```bash
    watch -n5 oc get pod -n baas
    ```
