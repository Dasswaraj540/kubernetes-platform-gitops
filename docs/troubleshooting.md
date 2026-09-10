# Troubleshooting concepts

A map of where to look when something misbehaves, by area.

## Delivery

| Symptom | Likely cause | Where to look |
|---|---|---|
| Argo CD app `OutOfSync` forever | prod is manual-sync by design | `argocd app get platform-api-prod`; run the sync |
| Argo CD app `Degraded` | a rendered object failed to apply | `argocd app diff platform-api-<env>`; `kubectl describe` the object; is the CRD installed? |
| Sync fails: "resource not allowed in project" | kind missing from the AppProject whitelist | `argocd/projects/platform.yaml` `namespaceResourceWhitelist` |
| `$values` file not found | path or `ref` mismatch | `argocd/apps/platform-api-<env>.yaml` — `ref: values` + `$values/argocd/envs/<env>/values.yaml` |
| Wrong env config applied | `releaseName` or `environment` value drift | every app sets `releaseName: platform-api`; each env file sets `environment:` |

## Workload

| Symptom | Likely cause | Where to look |
|---|---|---|
| `CrashLoopBackOff` at start | read-only rootfs with no writable `/tmp` | chart always mounts a `/tmp` `emptyDir`; check it rendered |
| Liveness kills the pod during boot | slow JVM start vs probe timing | `probes.startup` failureThreshold/period in values |
| Probes fail with connection refused | probe pointed at 8080 | probes must use port `management` (8081) |
| Pod can't resolve DNS | default-deny with no DNS egress | chart NetworkPolicy must allow `dnsNamespace` :53; `networkPolicy.dnsNamespace` |
| No traffic reaches the pod | ingress-controller namespace name mismatch | `networkPolicy.ingressControllerNamespace` |
| `ImagePullBackOff` | tag not published, or repo mismatch | CI published `ghcr.io/OWNER/platform-api:<sha>`; `image.repository` matches |

## Progressive delivery

| Symptom | Likely cause | Where to look |
|---|---|---|
| Rollout stuck at a step | analysis inconclusive or failing | `kubectl argo rollouts get rollout platform-api -n platform-<env>`; the `AnalysisRun` |
| Analysis errors "no data" | Prometheus address wrong, or `service` label absent | `argoRollouts.analysis.prometheusAddress`; ServiceMonitor scraping the canary Service |
| Canary never gets traffic | nginx traffic routing not wired | `strategy.canary.trafficRouting.nginx.stableIngress` must name the chart Ingress |

## Observability

| Symptom | Likely cause | Where to look |
|---|---|---|
| No `platform-api` series in Prometheus | ServiceMonitor label selector, or monitoring→8081 blocked | `serviceMonitor` values; NetworkPolicy `monitoringNamespace` |
| Alerts never fire | `PrometheusRule` not selected by Prometheus | `prometheusRule.additionalLabels` must match the Prometheus `ruleSelector` (often `release:`) |
| Grafana panels empty | datasource variable, or `namespace` template value | dashboard `templating` — pick the datasource and namespace |

## Authoring on Windows (Linux runtime target)

| Symptom | Fix |
|---|---|
| `./mvnw: bad interpreter: ^M` on Linux | `.gitattributes` forces `mvnw` / `*.sh` to LF; re-clone or `git add --renormalize .` |
| `./mvnw: Permission denied` on a CI runner | `git update-index --chmod=+x mvnw scripts/*.sh`; both pipelines also invoke via `bash`/`sh` |
| `kubectl`/`yq` chokes on a YAML file | a UTF-8 BOM from a PowerShell redirect; re-save UTF-8 without BOM (`.editorconfig` sets this) |
| A `.tf`/`.yaml` path not found on Linux CI but fine locally | case mismatch; all repo paths are lowercase |
