# Golden Topology QuickStart

## Experimental: QuickStart for Implementing Infrastructure Golden Topology

### Deploy OpenShift Container Storage and infrastructure+storage nodes

- Make sure you are logged in OpenShift with cluster-admin rights
    ```bash
    oc login ...
    ```

- Log in with the Github CLI
    ```bash
    gh auth login
    ```

- Setup a local git directory to clone all the git repositories
    ```bash
    mkdir -p infra-production
    cd infra-production
    ```

- Make sure you are connected to the correct OpenShift cluster
    ```bash
    oc whoami --show-console
    ```
- Setup an **empty** git organization to host your repos (you can also use your primary git userID, but that is provided that you do not have any multi-tenancy repos setup there)
    ```bash
    export GIT_ORG=<your_org>
    ```

- Fork and clone the multi-tenancy-gitops repos to your local directory:
    ```bash
    gh repo fork cloud-native-toolkit/multi-tenancy-gitops --clone --org ${GIT_ORG} --remote
    mv multi-tenancy-gitops gitops-0-bootstrap
    ```
- Modify the `kustomization.yaml` to add or remove features, the infrastructure capabilities are in `0-bootstrap/single-cluster/1-infra/kustomization.yaml` and you must enable the lines below:

    ```bash
    vi 0-bootstrap/single-cluster/1-infra/kustomization.yaml
    ```

    ```yaml
    resources:
    #- argocd/consolelink.yaml
    #- argocd/consolenotification.yaml
    #- argocd/namespace-ibm-common-services.yaml
    #- argocd/namespace-ci.yaml
    #- argocd/namespace-dev.yaml
    #- argocd/namespace-staging.yaml
    #- argocd/namespace-prod.yaml
    #- argocd/namespace-istio-system.yaml
    #- argocd/namespace-openldap.yaml
    #- argocd/namespace-sealed-secrets.yaml
    #- argocd/namespace-tools.yaml
    - argocd/namespace-openshift-storage.yaml
    - argocd/storage.yaml
    - argocd/infraconfig.yaml
    - argocd/machinesets.yaml
    ```

- Commit your changes to the `kustomization.yaml`

    ```bash
    git add 0-bootstrap/single-cluster/1-infra/kustomization.yaml
    git commit -m "Enable infrastructure components"
    git push origin
    ```

- Run the bootstrap script: specify the git org `GIT_ORG`, and the output directory to clone all repos `OUTPUT_DIR`. (Note: you can also specify the git user `GIT_USER`, the IBM Entitlement key value `IBM_ENTITLEMENT_KEY` and others if you are deploying additional features). You can use `DEBUG=true` for verbose output.
    ```bash
    cd ..
    curl -sfL https://raw.githubusercontent.com/cloud-native-toolkit/multi-tenancy-gitops/master/scripts/bootstrap.sh | \
    DEBUG=true GIT_ORG=$GIT_ORG OUTPUT_DIR=infra-production bash
    ```

- To get the ArgoCD/GitOps URL and admin password:
    ```bash
    oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}'
    oc extract secrets/openshift-gitops-cntk-cluster --keys=admin.password -n openshift-gitops --to=-
    ```

- Check the nodes being provisioned:

    ```bash
    watch -n5 oc get nodes,machines -n openshift-machine-api
    ```

    you should see your infra and storage nodes being provisioned and ready

    ```
    Every 5.0s: oc get nodes,machines -n openshift-machine-api                                             mbp.local: Fri Sep  3 11:11:36 2021

    NAME                                             STATUS   ROLES            AGE   VERSION
    node/z2g-cluster2-p45dl-infra-eastus21-z5znc     Ready    infra,worker     60m   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-infra-eastus22-8jwl8     Ready    infra,worker     62m   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-infra-eastus23-jzldd     Ready    infra,worker     62m   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-master-0                 Ready    master           45h   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-master-1                 Ready    master           45h   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-master-2                 Ready    master           45h   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-storage-eastus21-c47hz   Ready    storage,worker   60m   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-storage-eastus22-kn4z4   Ready    storage,worker   62m   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-storage-eastus23-zgqbl   Ready    storage,worker   62m   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-worker-eastus21-zb28l    Ready    worker           45h   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-worker-eastus22-hfbzx    Ready    worker           45h   v1.20.0+4593a24
    node/z2g-cluster2-p45dl-worker-eastus23-tkd6k    Ready    worker           45h   v1.20.0+4593a24

    NAME                                                                     PHASE     TYPE               REGION    ZONE   AGE
    machine.machine.openshift.io/z2g-cluster2-p45dl-infra-eastus21-z5znc     Running   Standard_D4s_v3    eastus2   1      65m
    machine.machine.openshift.io/z2g-cluster2-p45dl-infra-eastus22-8jwl8     Running   Standard_D4s_v3    eastus2   2      65m
    machine.machine.openshift.io/z2g-cluster2-p45dl-infra-eastus23-jzldd     Running   Standard_D4s_v3    eastus2   3      65m
    machine.machine.openshift.io/z2g-cluster2-p45dl-master-0                 Running   Standard_D8s_v3    eastus2   1      45h
    machine.machine.openshift.io/z2g-cluster2-p45dl-master-1                 Running   Standard_D8s_v3    eastus2   2      45h
    machine.machine.openshift.io/z2g-cluster2-p45dl-master-2                 Running   Standard_D8s_v3    eastus2   3      45h
    machine.machine.openshift.io/z2g-cluster2-p45dl-storage-eastus21-c47hz   Running   Standard_D16s_v3   eastus2   1      65m
    machine.machine.openshift.io/z2g-cluster2-p45dl-storage-eastus22-kn4z4   Running   Standard_D16s_v3   eastus2   2      65m
    machine.machine.openshift.io/z2g-cluster2-p45dl-storage-eastus23-zgqbl   Running   Standard_D16s_v3   eastus2   3      65m
    machine.machine.openshift.io/z2g-cluster2-p45dl-worker-eastus21-zb28l    Running   Standard_D8s_v3    eastus2   1      45h
    machine.machine.openshift.io/z2g-cluster2-p45dl-worker-eastus22-hfbzx    Running   Standard_D8s_v3    eastus2   2      45h
    machine.machine.openshift.io/z2g-cluster2-p45dl-worker-eastus23-tkd6k    Running   Standard_D8s_v3    eastus2   3      45h
    ```