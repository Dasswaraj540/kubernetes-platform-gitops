# Pod and namespace hardening

## Pod Security Admission

Each `platform-<env>` namespace is labelled (in `k8s/namespaces/platform-<env>.yaml`):

```
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/enforce-version: latest
pod-security.kubernetes.io/warn: restricted
pod-security.kubernetes.io/audit: restricted
```

`restricted` is the strictest built-in level: non-root, no privilege escalation, dropped
capabilities, a seccomp profile, and restricted volume types.

## How the chart satisfies `restricted`

From `helm/platform-api/values.yaml`, applied by `templates/_helpers.tpl`:

| Setting | Value | Reason |
|---|---|---|
| `podSecurityContext.runAsNonRoot` | `true` | container never runs as UID 0 |
| `podSecurityContext.runAsUser` / `runAsGroup` / `fsGroup` | `10001` | matches the image's `USER` |
| `podSecurityContext.seccompProfile.type` | `RuntimeDefault` | syscall filtering |
| `securityContext.allowPrivilegeEscalation` | `false` | no setuid escalation |
| `securityContext.readOnlyRootFilesystem` | `true` | tamper resistance; `/tmp` is an `emptyDir` |
| `securityContext.capabilities.drop` | `["ALL"]` | no Linux capabilities |
| `resources.requests` / `resources.limits` | set for CPU and memory | scheduling + blast-radius control |
| `probes.startup` / `liveness` / `readiness` | on port `8081` | correct lifecycle signalling |
| `terminationGracePeriodSeconds` + `lifecycle.preStop` | aligned with `server.shutdown: graceful` | no dropped in-flight requests |

## Namespace governance

`ResourceQuota` caps total CPU/memory/pod count per namespace. `LimitRange` sets container
defaults and a per-container maximum, so a pod without explicit requests still gets sane
values and cannot request the whole namespace.

## Verifying

```bash
kubectl -n platform-dev get pod -l app.kubernetes.io/name=platform-api \
  -o jsonpath='{.items[0].spec.securityContext}{"\n"}{.items[0].spec.containers[0].securityContext}'
kubectl -n platform-dev get resourcequota,limitrange
```
