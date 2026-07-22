# GitOps environments testing

## Directory structure

This repo uses a variation on the 'environment-per-folder' approach to organizing Helm values for deployments via ArgoCD.

At the top level, there are 3 directories:
- `common`: configuration/values that apply to *all* environments
- `envs`: contains directories for each specific environment. Those respective folders contain the configuraiton specific to that single environment.
- `variants`: contains directories for common characteristics between environments. If there are common settings for a well-defined subset of environments, those could be pulled into a variant.

## Example `ApplicationSet`

This ArgoCD `ApplicationSet` creates 3 applications for the following local environments: `dev`, `qa`, and `prod`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: dummyapp
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - list:
      elements:
      - env: dev
      - env: qa
      - env: prod
  template:
    metadata:
      name: dummyapp-{{.env}}
    spec:
      project: default
      sources:
      - path: helm-dummyapp
        repoURL: https://github.com/nrao/dummy-app.git
        targetRevision: helmchart-v0.4.0
        helm:
          valueFiles:
            - $values/common/dummyapp-values.yaml
            - $values/variants/local/dummyapp-values.yaml
            - $values/envs/local-{{.env}}/dummyapp-values.yaml
          parameters:
            - name: imageCredentials.password
              value: <token>
      - repoURL: https://github.com/kdion-nrao/gitops-envs-test.git
        targetRevision: HEAD
        ref: values
      destination:
        server: "https://kubernetes.default.svc"
        namespace: dummyapp-{{.env}}
      syncPolicy:
        automated:
          enabled: true
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

In this case, settings common to locally-run deployments are grouped in a `local` variant.

## Secrets

See [secrets.md](secrets.md)
