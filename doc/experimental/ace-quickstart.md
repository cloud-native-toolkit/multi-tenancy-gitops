# ACE QuickStart

## Experimental: QuickStart IBM Cloud Pak for Integration with ACE capability

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
- To get the ArgoCD/GitOps URL and admin password:
    ```bash
    oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}'
    oc extract secrets/openshift-gitops-cntk-cluster --keys=admin.password -n openshift-gitops --to=-
    ```
- After everything is installed get the Cloud Pak console and admin password
    ```bash
    oc get route -n tools integration-navigator-pn -o template --template='https://{{.spec.host}}'
    oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_username,admin_password --to=-
    ```

