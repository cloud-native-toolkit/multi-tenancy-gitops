# Cloud Native Toolkit Deployment Guides

To get started setup gitops operator and rbac on each cluster
```
oc apply -f setup/ocp47/
kubectl wait --for=condition=Established crd applications.argoproj.io
```

Apply the bootstrap profile
```
oc apply -f 0-bootstrap/argocd/bootstrap.yaml
```


This repository shows the reference architecture for gitops directory structure for more info https://cloudnativetoolkit.dev/learning/gitops-int/gitops-with-cloud-native-toolkit

