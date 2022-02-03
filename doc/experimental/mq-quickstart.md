# MQ QuickStart

## Experimental: QuickStart IBM Cloud Pak for Integration with MQ capability

### Deploy the MQ operator and its pre-requisites
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
    mkdir -p mq-production
    ```

- Make sure you are connected to the correct OpenShift cluster
    ```bash
    oc whoami --show-console
    ```

- Run the bootstrap script, specify the git org `GIT_ORG` and the output directory to clone all repos `OUTPUT_DIR`. You can use `DEBUG=true` for verbose output.  Note, the deployment of all selected resources will take 30 - 45 minutes.  
    ```bash
    curl -sfL https://raw.githubusercontent.com/cloud-native-toolkit-demos/multi-tenancy-gitops-mq/ocp47-2021-2/scripts/bootstrap.sh | DEBUG=true GIT_ORG=<YOUR_GIT_ORG> OUTPUT_DIR=mq-production bash
    ```

- You can open the output directory containing all the git repositories with VSCode
    ```bash
    code mq-production
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

### Execute pipelines to deploy a Queue Manager and Spring application to write messages to the queue.
- Before running the pipelines, verify the Platform Navigator and Common Services instances have been deployed successfully.
    ```bash
    oc get commonservice common-service -n ibm-common-services -o=jsonpath='{.status.phase}'
    # Expected output = Succeeded

    oc get platformnavigator -n tools -o=jsonpath='{ .items[*].status.conditions[].status }'
    # Expected output = True
    ```
- Configure the cluster with your GitHub Personal Access Token (PAT), update the `gitops-repo` Configmap which will be used by the pipeline to populate the forked gitops repository and add the `artifactory-access` Secret to the `ci` namespace.  Specify values for the `GIT_USER`, `GIT_TOKEN` and `GIT_ORG` environment variables.
    ```bash
    cd mq-production/gitops-3-apps/scripts

    curl -sfL https://raw.githubusercontent.com/cloud-native-toolkit-demos/multi-tenancy-gitops-apps/ocp47-2021-2/scripts/mq-kubeseal.sh | DEBUG=true GIT_USER=<GIT_USER> GIT_TOKEN=<GIT_TOKEN> GIT_ORG=<GIT_ORG> bash
    ```

    As this script executes it will issue a `git diff` to allow you to review
    its customizations.
    - Type `q` when you're finished examining the changes; the script will continue to completion.

- Run a pipeline to build and deploy a Queue Manager
    - Log in to the OpenShift Web Console.
    - Select Pipelines > Pipelines view in the `ci` namespace. 
    - Click the `mq-infra-dev` pipeline and select Actions > Start.
    - Provide the HTTPS URL for the `mq-infra` repository in your Git Organization.

- Run a pipeline to build and deploy a Spring application
    - Log in to the OpenShift Web Console.
    - Select Pipelines > Pipelines view in the `ci` namespace. 
    - Click the `mq-spring-app-dev` pipeline and select Actions > Start.
    - Provide the HTTPS URL for the `mq-spring-app` repository in your Git Organization.


