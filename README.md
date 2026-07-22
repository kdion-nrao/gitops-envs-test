# GitOps environments testing

## Directory structure

This repo uses a variation on the 'environment-per-folder' approach to organizing Helm values for deployments via ArgoCD.

At the top level, there are 3 directories:
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

## Secrets

See [secrets.md](secrets.md)
