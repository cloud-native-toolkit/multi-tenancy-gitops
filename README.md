# Cloud Native Toolkit GitOps Production Deployment Guides

- This repository shows the reference architecture for gitops directory structure for more info https://cloudnativetoolkit.dev/learning/gitops-int/gitops-with-cloud-native-toolkit


## Working with this repository

1. Create new repositories using these git repositories as templates
    - https://github.com/cloud-native-toolkit/multi-tenancy-gitops  <== this repository
    - https://github.com/cloud-native-toolkit/multi-tenancy-gitops-infra
    - https://github.com/cloud-native-toolkit/multi-tenancy-gitops-services
1. Install OpenShift GitOps Operator and ClusterRoles and deploy an instance
    ```bash
    oc apply -f setup/ocp47/
    while ! oc wait crd applications.argoproj.io --timeout=-1s --for=condition=Established  2>/dev/null; do sleep 30; done
    while ! oc wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n openshift-gitops > /dev/null; do sleep 30; done
    ```
1. Delete the default ArgoCD instance
    ```bash
    oc delete gitopsservice cluster -n openshift-gitops || true
    oc delete argocd openshift-gitops -n openshift-gitops || true
    ```
1. Create a custom ArgoCD instance with custom checks
    ```bash
    oc apply -f gitops-0-bootstrap/setup/ocp47/argocd-instance/ -n openshift-gitops
    while ! oc wait pod --timeout=-1s --for=condition=ContainersReady -l app.kubernetes.io/name=openshift-gitops-cntk-server -n openshift-gitops > /dev/null; do sleep 30; done
    ```
1. Run script to replace the git url and branch to your git organization where you created the git repositories
    ```bash
    GIT_ORG=acme-org GIT_BRANCH=master ./scripts/set-git-source.sh
    ```
1. Select a profile and delete the others from the `0-bootstrap` directory. For example `single-cluster`
    ```bash
    GITOPS_PROFILE="0-bootstrap/single-cluster"
    ```
1. Deploy ArgoCD Applications for each layer by uncommenting the lines in `kustomization.yaml` files. See the section bellow to see examples on which ArgoCD Apps to uncomment.
    - ${GITOPS_PROFILE}/1-infra/kustomization.yaml
    - ${GITOPS_PROFILE}/2-services/kustomization.yaml
1. Commit and push changes to your git repository
    ```bash
    git add .
    git commit -m "intial boostrap setup"
    git push origin
    ```
1. We deploy IBM Operator to the `tools` namespace, create the namespace and create container registry secret using your IBM ENTITLEMENT KEY. Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that is associated with the entitled software. In the Container software library tile, verify your entitlement on the View library page, and then go to **Get entitlement key** to retrieve the key.
    ```bash
    oc new-project tools || true
    oc create secret docker-registry ibm-entitlement-key -n tools \
    --docker-username=cp \
    --docker-password="<entitlement_key>" \
    --docker-server=cp.icr.io
    ```
1. Apply ArgoCD Bootstrap Application
    ```bash
    oc apply -f ${GITOPS_PROFILE}/bootstrap.yaml
    ```
1. To get the ArgoCD/GitOps URL and admin password:
    ```bash
    oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}'
    oc extract secrets/openshift-gitops-cntk-cluster --keys=admin.password -n openshift-gitops --to=-
    ```
1. After everything is installed get the Cloud Pak console and admin password
    ```bash
    oc get route -n tools integration-navigator-pn -o template --template='https://{{.spec.host}}'
    oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_username,admin_password --to=-
    ```

<details><summary>Deploying IBM Cloud Pak for Integration with ACE capability</summary>

## Deploying IBM Cloud Pak for Integration with ACE capability
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` uncomment the lines:
    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-ci.yaml
    - argocd/namespace-dev.yaml
    - argocd/namespace-staging.yaml
    - argocd/namespace-prod.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/namespace-tools.yaml
    ```
1. Edit the Shared Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` make sure your using the correction version for each operator, uncomment the lines:
    ```yaml
    - argocd/operators/ibm-ace-operator.yaml
    - argocd/operators/ibm-platform-navigator.yaml
    - argocd/instances/ibm-platform-navigator-instance.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/instances/ibm-foundational-services-instance.yaml
    - argocd/operators/ibm-automation-foundation-core-operator.yaml
    - argocd/operators/ibm-catalogs.yaml
    - argocd/instances/sealed-secrets.yaml
    ```
1. Edit the platform navigator to specify the storage class to use it needs to be ReadWriteMany(RWX) in the file `${GITOPS_PROFILE}/2-services/instances/ibm-platform-navigator-instance.yaml`
    ```yaml
    storage:
        class: managed-nfs-storage
    ```
1. After everything is installed get the Cloud Pak console and admin password
    ```bash
    oc get route -n tools integration-navigator-pn -o template --template='https://{{.spec.host}}'
    oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_username,admin_password --to=-
    ```
</details>



### Deploy the ACE operator and its pre-requisites
- Make sure you are logged in OpenShift with admin rights
    ```bash
    oc login ...
    ```

- Log in with the Github CLI
    ```bash
    gh auth login
    ```

- Setup a local git directory to clone all the git repositories
    ```bash
    mkdir -p ace-production
    ```

- Make sure you are connected to the correct OpenShift cluster
    ```bash
    oc whoami --show-console
    ```

- Run the bootstrap script, specify the git user `GIT_USER`, the git org `GIT_ORG`,the IBM Entitlement key value `GIT_TOKEN` and the output directory to clone all repos `OUTPUT_DIR`.You can use `DEBUG=true` for verbose output.
    ```bash
    curl -sfL https://raw.githubusercontent.com/cloud-native-toolkit/multi-tenancy-gitops/master/scripts/bootstrap.sh | \
    GIT_USER=$REPLACE_WITH_GIT_USER \
    GIT_ORG=$REPLACE_WITH_GIT_ORG \
    IBM_ENTITLEMENT_KEY="<entitlement_key>" \
    ACE_SCENARIO=true \
    OUTPUT_DIR=ace-production \
    sh
    ```
- You can open the output directory containing all the git repositories with VSCode
    ```bash
    code ace-production
    ```
1. To get the ArgoCD/GitOps URL and admin password:
    ```bash
    oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}'
    oc extract secrets/openshift-gitops-cntk-cluster --keys=admin.password -n openshift-gitops --to=-
    ```
1. After everything is installed get the Cloud Pak console and admin password
    ```bash
    oc get route -n tools integration-navigator-pn -o template --template='https://{{.spec.host}}'
    oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_username,admin_password --to=-
    ```

</details>