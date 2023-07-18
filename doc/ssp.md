# Deploy [Sterling Secure Proxy](https://www.ibm.com/docs/en/secure-proxy/6.0.3?topic=software-installing)

This recipe is for deploying the Sterling Secure Proxy Configuration Manager and Engine in a single namespace (i.e. `ssp`)

It makes the assumption that you already have a gitops ready cluster and have followed the setup protocols necessary to deploy ArgoCD. You will also require the gitops repos from the cloud native toolkit in your organization GitHub.

### Requirements

Sterling Secure Proxy requires Read-Write-Once persistent storage available and if you're using an NFS-style file structure, it will also require GID enabled storage or no root squash to be configured. Some recommended storage options are
   
   | IBM Cloud          | AWS                                                                  |
   |--------------------|----------------------------------------------------------------------|
   | ibmc-file-gold-gid | gp2 (or whatever the storage class of your Amazon EBS CSI Driver is) | 

### Multi-tenancy-gitops-services Repository

1. Under `instances/sterling-secure-proxy-configuration-manager` make sure that you review and make changes to the `values.yaml` file in the root level directory. You will need to fill out the `ibm-ssp-cm.persistentVolume` section, in particular the decision to use dynamic provisioning or to use an existing claim. I currently recommend the existing claim so that the keycert handoff job does not break. `ibm-ssp-cm.storageClassName` will also need to be updated with the correct RWO storage class for your cluster.

2. Double check `ibm-ssp-cm.storageSecurity` settings and ensure that the fsGroup and supplementalGroups matches the configuration necessary for your cluster. If it does not match, it will not install.

3. Select a name for your secret under `ibm-ssp-cm.secret.secretName` -> take note, this will change the secret on your cluster. Also take note, I have included basic base64 passwords to make demoing this gitops deployment easier, but in a production environment please replace this secret with a vault entrusted secret. An example of the workflow this would entail can be previewed with kubeseal and sealed secrets which are included in these repos. You can optionally deploy sealed secrets to the cluster and perform the following steps to configure your secrets for gitops:\
   \
   `kubeseal < secretname.yaml > sealedsecretname.yaml`\
   `kubectl apply -f sealedsecretname.yaml`\
   `kubectl delete secret originalsecretname`\
   You will now have a yaml file `sealedsecretname.yaml` that you can use for gitops as an alternative to the original secret. Push this file to your repo and remove the old secret template. Perform these steps for both the engine and the configuration manager.

4. `kubectl apply -f` both files in the `ibm-ssp-cm/prereqs` folder 

5. Now perform the same operations as steps 1-3 under `instances/sterling-secure-proxy-engine` with the additional field `ibm-ssp-engine.secret.keyCertSecretName` -> Note, I recommend you keep this set to `engine-key-cert` but it is not a hard requirement.

6. `kubectl apply -f` both files in the `ibm-ssp-engine/prereqs` folder

7. Push your changes to your git org

### Infrastructure - Kustomization.yaml
1. Edit the Infrastructure layer `multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra/kustomization.yaml` and uncomment the following

    ```yaml
   - argocd/namespace-ssp.yaml
   ```
   
2. Edit the Service layer `multi-tenancy-gitops/0-bootstrap/single-cluster/2-services/kustomization.yaml` and uncomment the following

    ```yaml
    - argocd/instances/sterling-secure-proxy-cm-instance.yaml
    - argocd/instances/sterling-secure-proxy-engine-instance.yaml
    ```
   
3. Push these changes to your git org and perform an ArgoCD sync. If you've configured everything correctly then you should see the Sterling Secure Proxy configuration manager spin up under the `ssp` namespace, followed by a `key-cert-handoff-job` which will populate the `engine-key-cert` secret that your engine requires to spin itself up. Then your engine will spin up. You may now increase the number of replicas on the installation to your desired size.