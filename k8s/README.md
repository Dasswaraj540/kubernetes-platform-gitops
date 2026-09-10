# `k8s/` — cluster bootstrap

These manifests are applied **once per cluster**, before Argo CD takes ownership of the
`platform-*` namespaces. They are cluster and namespace governance, not workload
configuration. Everything that describes the `platform-api` workload lives in the Helm chart
at [`helm/platform-api`](../helm/platform-api) and is delivered by Argo CD — see
[`docs/gitops.md`](../docs/gitops.md).

| Path | Contents | Why it is here and not in the chart |
|---|---|---|
| `namespaces/platform-<env>.yaml` | `Namespace` (Pod Security Admission `restricted`), `ResourceQuota`, `LimitRange`, and a `default-deny` `NetworkPolicy` | The namespace must exist with its guardrails before Argo CD syncs into it. Argo CD Applications use `CreateNamespace=false`. |
| `rbac/platform-access.yaml` | A read-only `platform-viewer` `ClusterRole` and per-namespace `RoleBinding`s | Human/team access is a cluster concern. The chart's RBAC is only the workload ServiceAccount's own namespaced `Role`. No subject appears in both. |

## Apply order

```bash
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/rbac/
```

## Notes

- The `default-deny` `NetworkPolicy` in each namespace denies all ingress and egress. The
  Helm chart then re-opens exactly what `platform-api` needs (ingress-controller → 8080,
  monitoring → 8081, DNS egress) via its own `NetworkPolicy`. Read the two together.
- RBAC subjects (`platform-developers`, `platform-sre`) are placeholders. Map them to real
  IdP groups, or replace with `User` / `ServiceAccount` subjects, before applying.
- Quotas and limit ranges are starting points sized for a shared cluster, not measured
  figures. Adjust to the target node pools.
