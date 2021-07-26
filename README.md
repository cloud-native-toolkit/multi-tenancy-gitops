# Cloud Native Toolkit Deployment Guides

## Working with forks
Fork this repo then rename git references using script
```
GIT_USER=<git org or user> ./scripts/set-git-source.sh
```

## Install OpenShfit GitOps (ArgoCD)
To get started setup gitops operator and rbac on each cluster

- For OpenShift 4.7+ use the following:
```
oc apply -f setup/ocp47/
while ! kubectl wait --for=condition=Established crd applications.argoproj.io; do sleep 30; done
oc extract secrets/openshift-gitops-cluster --keys=admin.password -n openshift-gitops --to=-
```

- For OpenShift 4.6 use the following:
```
oc apply -f setup/ocp46/
while ! kubectl wait --for=condition=Established crd applications.argoproj.io; do sleep 30; done
oc extract secrets/argocd-cluster-cluster --keys=admin.password -n openshift-gitops --to=-
```

## Install the ArgoCD Application Bootstrap
Apply the bootstrap profile, to use the default `single-cluster` scenario use the following command:
```
oc apply -n openshift-gitops -f 0-bootstrap/argocd/bootstrap.yaml
```

For other profile clusters set environment variable `TARGET_CLUSTER` then apply the profile

**shared-cluster**:
```
TARGET_CLUSTER=0-bootstrap/argocd/others/1-shared-cluster/bootstrap-cluster-1-cicd-dev-stage-prod.yaml

TARGET_CLUSTER=0-bootstrap/argocd/others/1-shared-cluster/bootstrap-cluster-n-prod.yaml
```
Now apply the profile
```
echo TARGET_CLUSTER=${TARGET_CLUSTER}
oc apply -n openshift-gitops -f ${TARGET_CLUSTER}
```


This repository shows the reference architecture for gitops directory structure for more info https://cloudnativetoolkit.dev/learning/gitops-int/gitops-with-cloud-native-toolkit

