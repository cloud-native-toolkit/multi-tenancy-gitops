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

Assuming you are running under `multi-tenancy-gitops` repo or `gitops-0-bootstrap` directory - you can prepare your environment such as the following:

```bash
export GIT_ORG=<org>
export IBM_ENTITLEMENT_KEY=<entitlement>
export GITHUB_TOKEN=<git-token>
echo ${GITHUB_TOKEN} | gh auth login --with-token
oc login . . .
git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops
cd multi-tenancy-gitops
```

Depending on whether you want to install Spectrum Protect Plus and/or Container Backup Support feature, you can do either one of these:

- Installing both SPP and BaaS:

    ``` bash
    DEPLOYSPP=true DEPLOYBAAS=true SPPUSER=sppadmin SPPPW=passw0rd ADMINUSER=baasadmin ADMINPW=passw0rd ./scripts/spp-bootstrap.sh
    ```

- Installing only SPP

    ``` bash
    DEPLOYSPP=true DEPLOYBAAS=false SPPUSER=sppadmin SPPPW=passw0rd ./scripts/spp-bootstrap.sh
    ```

- Installing only BaaS

    ``` bash
    DEPLOYSPP=false DEPLOYBAAS=true SPPUSER=sppadmin SPPPW=passw0rd ADMINUSER=baasadmin ADMINPW=passw0rd SPPFQDN="ibmspp.apps.sppserver.domain.com" ./scripts/spp-bootstrap.sh
    ```

### Validation
1.  Login to the IBM Specrum Protect plus UI: 
    ```bash
    # Retrieve Platform Navigator Console URL
    oc get route -n spp sppproxy -o template --template='https://{{.spec.host}}'
    # Retrieve admin password
    oc extract -n spp secrets/sppadmin --keys=adminUser,adminPassword --to=-
    ```
