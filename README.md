# Cloud Native Toolkit Deployment Guides


## Install OpenShfit GitOps (ArgoCD)
To get started setup gitops operator and rbac on each cluster

- For OpenShift 4.7+ use the following:
```
oc apply -f setup/ocp47/
kubectl wait --for=condition=Established crd applications.argoproj.io
```

- For OpenShift 4.6+ use the following:
```
oc apply -f setup/ocp47/
kubectl wait --for=condition=Established crd applications.argoproj.io
```

## Install the ArgoCD Application Bootstrap
Apply the bootstrap profile, to use the default `single-cluster` scenario use the following command:
```
oc apply -f 0-bootstrap/argocd/bootstrap.yaml
```



This repository shows the reference architecture for gitops directory structure for more info https://cloudnativetoolkit.dev/learning/gitops-int/gitops-with-cloud-native-toolkit

