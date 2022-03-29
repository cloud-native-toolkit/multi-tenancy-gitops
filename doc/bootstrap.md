# Bootstraping an OpenShift cluster for Production Reference Architecture

This documentation is for initializing an OpenShift cluster for GitOps operation using the `bootstrap.sh`. Running the `bootstrap.sh` requires the following:

- Active connectivity to a running OpenShift cluster
- Access to an available GIT-like repository 
- Availability of a set of CLI tools, including:
    - oc
    - git
    - curl
    - sed
- Git repository specific CLI tools (only if you use the tools)
    - gh (GitHub CLI)
    - glab (GitLab CLI)
- The following are some environment variables that are used:
    - `IBM_ENTITLEMENT_KEY`
    - `SEALED_SECRET_KEY_FILE` - if using sealed secrte 


The bootstrap.sh can perform the following:

1. Prepare the GIT repository, the following environment variables are needed:

    - `GIT_ORG` (org name for the repo - required)
    - `GIT_TARGET` (currently support `github`, `gitea` and `gitlab`, default to `github`)
    - `GIT_BRANCH` (typically `master` or `main`, default to `master`)
    - `GIT_HOST` (default to `github.com` - change as needed for gitlab or other; not needed for in-cluster repo)
    - `GIT_TOKEN` (for GitHub and GitLab)
    - `GIT_USER`  (for GitHub and GitLab)

2. Setup argoCD with custom health check

3. Setup GIT environment using `set-get-source.sh` and setting the RWX storage class from `RWX_STORAGECLASS` environment variable. Then adding commits to the repo