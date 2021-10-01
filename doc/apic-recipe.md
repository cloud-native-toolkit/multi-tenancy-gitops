# Deploy Cloud Pak for Integration - IBM API Connect capability

## Overview

This IBM API Connect recipe should provide a highly available deployment of IBM API Connect on a Red Hat OpenShift Kubernetes Service on IBM Cloud as shown below.

![apic-qs](images/apic-qs.png)

### Infrastructure - kustomization.yaml
1. Edit the Infrastructure layer `${GITOPS_PROFILE}/1-infra/kustomization.yaml` and un-comment the following:
    ```yaml
    - argocd/namespace-ibm-common-services.yaml
    - argocd/namespace-tools.yaml
    ```
### Services - kustomization.yaml    
1. Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` uncomment the following:
    ```yaml
    - argocd/operators/ibm-apic-operator.yaml
    - argocd/instances/ibm-apic-instance.yaml
    - argocd/operators/ibm-datapower-operator.yaml
    - argocd/operators/ibm-foundations.yaml
    - argocd/operators/ibm-catalogs.yaml
    ```
### Storage - ibm-apic-instance.yaml
1. Make sure the `storageClassName` specified in `${GITOPS_PROFILE}/2-services/argocd/instances/ibm-apic-instance.yaml`, which defaults to the **`ibm-block-gold`**, corresponds to an available **block** storage class in the cluster you are executing this recipe in.

### High Availability - ibm-apic-instance.yaml
1. Make sure the `profile` specified in `${GITOPS_PROFILE}/2-services/argocd/instances/ibm-apic-instance.yaml`, which defaults to the **`n3xc14.m48`**, corresponds to the desired profile: development vs production.

    * `n1xc10.m48` - Deploys 1 replica of each pod, so this profile is most suitable for a small, non-HA system. Recommended use of this profile is for development and testing.

    * `n3xc14.m48` - Deploys 3 or more replicas of each pod, so this profile is most suitable for larger systems and for production environments. This profile is supported for installation on a cluster with three or more nodes. It is not supported on a cluster with fewer than three nodes.

**IMPORTANT:** Make sure the Red Hat OpenShift cluster you are deploying this IBM API Connect recipe to has been sized appropriately based on the profiles above where:

* `n` stands for the number of worker nodes.
* `c` stands for the amount of CPU per worker node.
* `m` stands for the amount of RAM per worker node.