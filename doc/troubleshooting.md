# Cloud Native Toolkit - GitOps Production Deployment Guide - Troublehsooting Tips

**Work in progress - Updating coming soon**

## Problems with GIT repository


- Unable to push to a private git repository (GITEA, GOGS etc)

    ```
    git config --global http.sslVerify false
    ```

    remember to re-enable sslVerify afterwards or make sure that the repository is using a proper certificate.


- Unable to reach private git repository (GITEA, GOGS etc) from argoCD: 

    ```
    argocd repo add --insecure-skip-server-verification https://gitea-tools.apps.cluster.domain.com/gitorg/multi-tenancy-gitops
    ```
    
    This potentially open a man-in-the-middle attack that can impersonate the source git - hence make the cluster vulnerable; you should get a proper certificate for your git repository.


- Pushing to git hung after the 100% completed but never actually sent (running with `-v` option shows `POST git-receive-pack (chunked)` as the last message)

    ```
    git config http.postBuffer 4096
    ```