# GitOps environments testing

## Apps

```mermaid
architecture-beta
    group dummy["AppProject: releng-dummyapp-demo"]

        group dummy_env(internet)["AppSet: dummy-app-deployments"] in dummy
            service dev(server)["dummy-app-dev"] in dummy_env
            service qa(server)["dummy-app-qa"] in dummy_env

        group dummy_pr(internet)["AppSet: dummy-app-pr-previews"] in dummy
            service pr_n(cloud)["dummyapp-pr-#"] in dummy_pr
            service pr_x(cloud)["dummyapp-pr-#"] in dummy_pr

    service ksops(server)["ksops-secrets"]

    align row ksops dev qa
    align row pr_n pr_x
    align column dev pr_n
```

## Directory structure

This repo uses a variation on the 'environment-per-folder' approach to organizing Helm values for deployments via ArgoCD.

At the top level, there are several directories:
- `apps`: Contains the ArgoCD definitions that are meant to be loaded by an 'app-of-apps'
- `common`: configuration/values that apply to *all* environments
- `envs`: contains directories for each specific environment. Those respective folders contain the configuraiton specific to that single environment.
- `variants`: contains directories for common characteristics between environments. If there are common settings for a well-defined subset of environments, those could be pulled into a variant.

## Example 'App of Apps' root app

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/kdion-nrao/gitops-envs-test.git
    targetRevision: HEAD
    path: apps
    directory:
      recurse: true
      include: '*.yaml'
      exclude: 'ksops/*'
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

```

## Using the separated Helm values in an ArgoCD Application:

In an ArgoCD Application spec, you would specify the Helm chart repo as the primary source, and this repo as a secondary reference. The layers of values should then be included in the correct order to achieve the proper layering, e.g.:

```yaml
spec:
  sources:
    - repoURL: 'https://github.com/nrao/dummy-app/'
      path: helm-dummyapp
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
          - $values/common/dummyapp-values.yaml           # <--- Common values first
          - $values/common/dummyapp-secrets.enc.yaml      # <---        (and secrets)
          - $values/variants/local/dummyapp-values.yaml   # <--- Variant(s) applied next
          - $values/envs/local-dev/dummyapp-values.yaml   # <--- Finally the most precise level, the specific environment
    - repoURL: https://github.com/kdion-nrao/gitops-envs-test.git
      targetRevision: HEAD
      ref: values
```

## Secrets

See [secrets.md](secrets.md)
