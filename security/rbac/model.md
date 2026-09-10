# Kubernetes RBAC model

Two disjoint sets of subjects. No subject appears in both.

## Workload identity (chart-owned)

`helm/platform-api/templates/{serviceaccount,role,rolebinding}.yaml`:

- ServiceAccount `platform-api` in the workload namespace.
- A namespaced `Role` granting `get` / `list` / `watch` on **one** ConfigMap — the app's own
  `platform-api-config`. Nothing else.
- A `RoleBinding` tying the two together.

The pod therefore has no ability to read Secrets, list pods, or touch anything outside its
own config. Cloud permissions come from IRSA (see `../iam/least-privilege.md`), not from the
Kubernetes API.

Gate: `rbac.create` (default `true`). Set it `false` if a platform policy provisions the
Role out of band.

## Human / team access (`k8s/rbac`)

`k8s/rbac/platform-access.yaml`:

- A single `platform-viewer` `ClusterRole`: read-only on pods, pod logs, services,
  configmaps, deployments, replicasets, HPAs, and Argo Rollouts / AnalysisRuns, plus
  `metrics.k8s.io` pods.
- One `RoleBinding` per namespace binding that ClusterRole to a group
  (`platform-developers` for dev/staging, `platform-sre` for prod).

There is no write access and no `cluster-admin` binding anywhere. Deploys happen through
Argo CD, not `kubectl`.

## If you need a deployer role

Grant it to the Argo CD application controller's ServiceAccount (installed with Argo CD),
scoped by the `platform` `AppProject`'s `namespaceResourceWhitelist` — not to human users.
