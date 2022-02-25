# Deploy Sterling Secure File Gateway

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml`,  un-comment the following lines, commit and push the changes and synchronize the `infra` Application in the ArgoCD console.
    ```yaml
    - argocd/consolenotification.yaml
    - argocd/namespace-db2.yaml
    - argocd/namespace-mq.yaml
    - argocd/namespace-tools.yaml
    - argocd/namespace-sealed-secrets.yaml
    - argocd/serviceaccounts-db2.yaml
    - argocd/serviceaccounts-mq.yaml
    - argocd/serviceaccounts-tools.yaml
    ```

### Services - Kustomization.yaml
1. This recipe is currently set to use storageclasses provided by IBM Cloud.
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Sealed Secrets by uncommenting the following line, commit and push the changes and synchronize the `services` Application in the ArgoCD console.
    ```yaml
    - argocd/instances/sealed-secrets.yaml
    ```
1. Generate Sealed Secrets resources required by Sterling Secure File Gateway.

    1. From a terminal window and clone the `multi-tenancy-gitops-services` repository using your Git Organization.
        ```
        git clone git@github.com:${GIT_ORG}/multi-tenancy-gitops-services.git
        cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi-setup
        ```
    1. Generate a Sealed Secret for the DB2 credentials.
        ```
        B2B_DB_SECRET=db2inst1 ./b2b-db-secret-secret.sh
        ```
    1. Generate a Sealed Secret for the MQ credentials, keystore and truststore password.
        ```
        JMS_PASSWORD=password JMS_KEYSTORE_PASSWORD=password JMS_TRUSTSTORE_PASSWORD=password ./b2b-jms-secret.sh
        ```
    1. Generate a Sealed Secret for the B2B System Passphrase.
        ```
        B2B_SYSTEM_PASSPHRASE_SECRET=password ./b2b-system-passphrase-secret.sh
        ```

1. Generate Persistent Volume Yamls required by Sterling Secure File Gateway:
    ```
    ./ibm-b2bi-documents-pv.sh
    ./ibm-b2bi-logs-pv.sh
    ./ibm-b2bi-resources-pv.sh
    ./sterlingtoolkit-pv.sh
    ```
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following lines to install the pre-requisites for Secure File Gateway, commit and push the changes and synchronize the `services` Application in the ArgoCD console.
    ```yaml
    - argocd/instances/ibm-db2.yaml
    - argocd/instances/ibm-mq.yaml
    - argocd/instances/ibm-sfg-b2bi-setup.yaml
    ```
1. Generate Helm Chart values.yaml for the Sterling Secure File Gateway Helm Chart:
    ```
    cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi
    ./ibm-sfg-b2bi-overrides-values.sh
    ```
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following line to install Secure File Gateway, commit and push the changes and synchronize the `services` Application in the ArgoCD console:
    ```yaml
    - argocd/instances/ibm-sfg-b2bi.yaml
    ```

### Validation
1.  Retrieve the Secure File Gateway console URL.
    ```bash
    oc get route -n tools ibm-sfg-b2bi-sfg-asi-internal-route-filegateway -o template --template='https://{{.spec.host}}'
    ```
2. Log in with the default credentials: `fg_sysadmin / password`.
