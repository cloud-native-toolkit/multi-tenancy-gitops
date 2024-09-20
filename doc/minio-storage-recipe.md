# Deploy [Minio-IO](https://min.io/docs/minio/kubernetes/upstream/index.html?ref=docs-redirect)

This recipe is for deploying Minio-IO in a single namespace (`Minio-Dev`)


## Infra-Setup
1. Navigate to "multi-tenancy-gitops/0-bootstrap/single-cluster/1-infra/kustomization.yaml"
2. Open it and un-comment the followng line

    ```bash
    argocd/namespace-minio.yaml
    ```

3. Save and close the file
4. Navigate to "multi-tenancy-gitops/0-bootstrap/single-cluster/2-services/kustomization.yaml"
5. open it and un-comment the following line

    ```bash
    argocd/instances/minio-app.yaml
    ```
6. save and close the file
7. Commit and Push the changes for `multi-tenancy-gitops` 

## Services
In the services section, there are 2 files you could modify according to your deployment paramenters,

1. The resources yaml which is respnsible for creating the PVC (Where you can change the storage class name if needed)

2. The deployment yaml which builds the pod for the minio deployment (Where you can specify a node for your pod to be deployed on if needed)

>  💡 **NOTE** You can access them both under by navigating to this folder --> multi-tenancy-gitops-services\instances\minio-io


## Validation section

1. You can verify the state of the pod by running the following command

     ```bash
    kubectl get pods -n minio-dev
    ```
2. The output should resemble the following,

     ```bash
    NAME    READY   STATUS    RESTARTS   AGE
    minio   1/1     Running   0          77s
    ```

### Temporarily Access the MinIO S3 API and Console

3. You use the kubectl port-forward command to temporarily forward traffic from the MinIO pod to the local machine

     ```bash
    kubectl port-forward pod/minio 9000 9090 -n minio-dev
    ```

4. Access the MinIO Console by opening a browser on the local machine and navigating to http://127.0.0.1:9090

5. Log in to the Console with the credentials `minioadmin` | `minioadmin`. These are the default root user credentials.