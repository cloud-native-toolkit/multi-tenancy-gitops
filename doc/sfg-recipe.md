# Deploy Sterling Secure File Gateway

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
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
1. This recipe is currently set to use storageclasses provdided by IBM Cloud.
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Sealed Secrets by uncommenting the following:
    ```yaml
    - argocd/instances/sealed-secrets.yaml
    ```
1. Generate Sealed Secrets for `ibm-sfg-b2bi-setup`:
    ```
    cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi-setup
    B2B_DB_SECRET=db2inst1 ./b2b-db-secret-secret.sh
    JMS_PASSWORD=password JMS_KEYSTORE_PASSWORD=password JMS_TRUSTSTORE_PASSWORD=password ./b2b-jms-secret.sh
    B2B_SYSTEM_PASSPHRASE_SECRET=password ./b2b-system-passphrase-secret.sh
1. Generate Persistent Volume Yamls for ibm-sfg-b2bi-setup:
    ```
    ./ibm-b2bi-documents-pv.sh
    ./ibm-b2bi-logs-pv.sh
    ./ibm-b2bi-resources-pv.sh
    ./sterlingtoolkit-pv.sh
    ```
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install the pre-requisites for Secure File Gateway:
    ```yaml
    - argocd/instances/ibm-db2.yaml
    - argocd/instances/ibm-mq.yaml
    - argocd/instances/ibm-sfg-b2bi-setup.yaml
    ```
1. Generate Helm Chart values.yaml for `ibm-sfg-b2bi`:
    ```
    cd multi-tenancy-gitops-services/instances/ibm-sfg-b2bi
    ./ibm-sfg-b2bi-overrides-values.sh
    ```
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` and install Secure File Gateway:
    ```yaml
    - argocd/instances/ibm-sfg-b2bi.yaml
    ```


### Validation
1.  Log in to the Platform Navigator console
    ```bash
    # Retrieve Platform Navigator Console URL
    oc get route -n tools ibm-sfg-b2bi-sfg-asi-internal-route-filegateway -o template --template='https://{{.spec.host}}'
    ```
2. Log in with `fg_sysadmin / password`.
