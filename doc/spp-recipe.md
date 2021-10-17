# Deploy IBM Spectrum Protect Plus 

This recipe is for deploing IBM Spectrum Protect Plus

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-tools.yaml
    - argocd/namespace-spp.yaml
    - argocd/namespace-spp-velero.yaml
    - argocd/namespace-baas.yaml
    ```
### Services - Kustomization.yaml

1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/instances/sealed-secrets.yaml
    - argocd/operators/spp-catalog.yaml
    - argocd/operators/spp-operator.yaml
    - argocd/instances/spp-instance.yaml
    - argocd/instances/spp-postsync.yaml
    - argocd/operators/oadp-operator.yaml
    - argocd/instances/oadp-instance.yaml
    - argocd/operators/baas-operator.yaml
    - argocd/instances/baas-instance.yaml
    ```

1. Modify the content for the Service layer values in `${GITOPS_PROFILE}/2-services/argocd/instances/spp-instance.yaml`

2. Modify the content for the Service layer values in `${GITOPS_PROFILE}/2-services/argocd/instances/baas-instance.yaml`

**Note**: The script in `${GITOPS_PROFILE}/scripts/spp-bootstrap.sh` can perform all these magic automatically

### Validation
1.  Login to the IBM Specrum Protect plus UI: 
    ```bash
    # Retrieve Platform Navigator Console URL
    oc get route -n spp sppproxy -o template --template='https://{{.spec.host}}'
    # Retrieve admin password
    oc extract -n spp secrets/sppadmin --keys=adminUser,adminPassword --to=-
    ```
