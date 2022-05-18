# Deploy OpenShift Container Storage

> ###### Note
> This recipe does not work in ROKS clusters.
>
> For ROKS clusters, please follow the [ROKS documentation](https://cloud.ibm.com/docs/openshift?topic=openshift-deploy-odf-vpc)

## Infrastructure - Kustomization.yaml

1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
  
    ```yaml
    - argocd/namespace-openshift-storage.yaml
    - argocd/storage.yaml
    - argocd/machinesets.yaml
    ```
  
2. Update MachineSet Parameters in `${GITOPS_PROFILE}/1-infra/argocd/machinesets.yaml`

    ```yaml
    values: |
      refarch-machinesets:
        infrastructureId: "${INFRASTRUCTURE_ID}"
        cloudProvider:
          name: "${PLATFORM}" 
          managed: ${MANAGED}
        cloud:
          region: ${REGION}
          image: ${IMAGE_NAME}
    ```

    `INFRASTRUCTURE_ID` is the unique identifier for your cluster

    ```bash
    INFRASTRUCTURE_ID=$(oc get -o jsonpath='{.status.infrastructureName}' infrastructure cluster)
    ```

    `PLATFORM` is the cloud provider your cluster is deployed into.  Can be any of the following:
    - aws
    - azure
    - vsphere

    `MANAGED` is a boolean value that determines if the cluster is managed by your cloud provider.  Set to `true` for `ROSA` and `ARO`, otherwise set to `false`.

    `REGION` is the region your cluster is deployed into

    `IMAGE_NAME` is the boot image for your cluster virtual machines

    ```bash
    majorVer=$(oc get -o jsonpath='{.items[].spec.channel}' clusterversion | cut -d- -f2)
    RHCOS_URL="https://raw.githubusercontent.com/openshift/installer/release-${majorVer}/data/data/rhcos.json"
    if echo $majorVer | grep -E '4.[1-9][0-9]' > /dev/null ; then
        RHCOS_URL="https://raw.githubusercontent.com/openshift/installer/release-${majorVer}/data/data/coreos/rhcos.json"
    fi
    if [[ "$PLATFORM" == "aws"  ]]; then
        IMAGE_NAME=$(curl -k -s $RHCOS_URL | grep -A1 "${REGION}" | grep hvm | cut -d'"' -f4)
        elif [[ "$platform" == "azure"  ]]; then
        IMAGE_NAME=$(curl -k -s $RHCOS_URL | grep -A3 "azure" | grep '"image"' | cut -d'"' -f4)
        elif [[ "$platform" == "gcp"  ]]; then
        IMAGE_NAME=$(curl -k -s $RHCOS_URL | grep -A3 "gcp" | grep '"image"' | cut -d'"' -f4)
        elif [[ "$platform" == "ibmcloud"  ]]; then
        IMAGE_NAME=$(curl -k -s $RHCOS_URL | grep -A3 "ibmcloud" | grep '"path"' | cut -d'"' -f4)
    fi
    ```

3. Update Storage Parameters in `${GITOPS_PROFILE}/1-infra/argocd/storage.yaml`

    ```yaml
    values: |
      ${STORAGE_CHART_NAME}:
        channel: ${CHANNEL}
        sizeGiB: ${STORAGE_SIZE}
        storageClass: ${STORCLASS}
        argo:
          namespace: ${GIT_GITOPS_NAMESPACE}
          serviceAccount: openshift-gitops-cntk-argocd-application-controller
    ```

    `STORAGE_CHART_NAME` is the name of the storage chart for your cluster
    - For OCP version 4.6 through 4.8, use STORAGE_CHART_NAME=ocs-operator
    - For OCP version 4.9 and greater, use STORAGE_CHART_NAME=odf-operator

    `CHANNEL` is the subscription channel for your storage operator, in the form of stable-4.x where `x` is the minor version of OpenShift eg 4.`9`

    `STORAGE_SIZE` is the size, in GiBs of your storage cluster. Set to `512` for small clusters.

    `STORCLASS` is the default storage class on your cluster

    ```bash
    STORCLASS=$(oc get storageclass | grep default | cut -d" " -f1)
    ```

    `GIT_GITOPS_NAMESPACE` is the namespace where the ArgoCD instance is installed.  The default ArgoCD namespace is `openshift-gitops`
