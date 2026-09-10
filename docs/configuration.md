# Configuration model

Configuration is kept separate from the container image at every layer. The image is
byte-identical across environments; only values differ.

## Layers

| Layer | Mechanism | Lives in | Changes per environment? |
|---|---|---|---|
| Application settings | Environment variables → `@ConfigurationProperties` | `app/src/main/resources/application.yml` (defaults + binding) | via the chart ConfigMap / env |
| JVM / container | `JAVA_OPTS` env, container-aware flags | `docker/Dockerfile` ENTRYPOINT, chart `env` | rarely |
| Workload defaults | Helm values | `helm/platform-api/values.yaml` | no (defaults) |
| Environment overrides | Helm values | `argocd/envs/<env>/values.yaml` | yes |
| Validation | JSON Schema | `helm/platform-api/values.schema.json` | no |
| Secrets | `ExternalSecret` → `platform-api-secrets`, `envFrom` | `helm/platform-api/templates/externalsecret.yaml` + `security/secrets/` | values only (keys), never values |

## Application environment variables

All optional; defaults in `application.yml`. Names are the canonical contract — the chart
ConfigMap and any docs must use these exact keys.

| Variable | Default | Purpose |
|---|---|---|
| `SERVER_PORT` | `8080` | Public HTTP port (`server.port`) |
| `MANAGEMENT_SERVER_PORT` | `8081` | Actuator / probe / metrics port (`management.server.port`) |
| `PLATFORM_INFO_ENVIRONMENT` | `local` | Reported by `GET /api/v1/info` |
| `PLATFORM_INFO_REGION` | `unknown` | Reported by `GET /api/v1/info` |
| `PLATFORM_ITEMS_SEED_COUNT` | `5` | Number of in-memory seed items |
| `PLATFORM_ITEMS_MAX_PAGE_SIZE` | `50` | Upper bound on `GET /api/v1/items?size=` |
| `SPRING_PROFILES_ACTIVE` | _(unset)_ | Spring profile selection |
| `JAVA_OPTS` | _(see Dockerfile)_ | Extra JVM flags |
| `OTEL_SDK_DISABLED` | `true` | Set `false` (and enable the agent) to emit traces |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | _(unset)_ | Collector endpoint when tracing is enabled |
| `OTEL_SERVICE_NAME` | `platform-api` | Trace resource attribute |

`GET /api/v1/info` returns the build coordinates (`0.1.0`), `PLATFORM_INFO_ENVIRONMENT`,
and `PLATFORM_INFO_REGION`. It does not echo arbitrary environment variables.

## Helm values → template map

The authoritative list is `helm/platform-api/values.yaml` (documented inline) and its
schema. Top-level keys:

| Key | Controls |
|---|---|
| `image.repository` / `image.tag` / `image.pullPolicy` | container image; `tag` is CI-written per environment |
| `replicaCount` | replicas when autoscaling is disabled |
| `resources.requests` / `resources.limits` | CPU/memory; always set |
| `podSecurityContext` / `securityContext` | the hardening block (non-root 10001, RO rootfs, drop caps, seccomp) |
| `probes.liveness` / `probes.readiness` / `probes.startup` | probe timing; paths fixed to `/actuator/health/*` on `management` |
| `service.port` / `service.managementPort` | `8080` / `8081` |
| `ingress.enabled` / `ingress.host` / `ingress.tls.enabled` | Ingress; host is per-environment |
| `autoscaling.enabled` / `minReplicas` / `maxReplicas` / `targetCPUUtilizationPercentage` / `targetMemoryUtilizationPercentage` | HPA |
| `pdb.enabled` / `pdb.minAvailable` | PodDisruptionBudget |
| `networkPolicy.enabled` / `networkPolicy.ingressControllerNamespace` / `networkPolicy.monitoringNamespace` / `networkPolicy.dnsNamespace` | NetworkPolicy peers |
| `topologySpread.enabled` / `topologySpread.maxSkew` | topology spread constraints |
| `rbac.create` | Role + RoleBinding |
| `serviceAccount.create` / `serviceAccount.roleArn` | ServiceAccount + IRSA annotation |
| `argoRollouts.enabled` / `argoRollouts.steps` / `argoRollouts.analysis.*` | Deployment vs Rollout; canary steps; analysis |
| `argoRollouts.analysis.prometheusAddress` | Prometheus URL for the AnalysisTemplate |
| `serviceMonitor.enabled` / `serviceMonitor.interval` | ServiceMonitor |
| `prometheusRule.enabled` / `prometheusRule.thresholds.*` | PrometheusRule alerts |
| `externalSecrets.enabled` / `externalSecrets.secretStoreRef` / `externalSecrets.data` | ExternalSecret |
| `otel.enabled` / `otel.endpoint` / `otel.samplerArg` | OpenTelemetry Java agent wiring |
| `config` | map written into the `platform-api-config` ConfigMap, loaded via `envFrom` |
| `extraEnv` | additional container environment variables (list of `name`/`value`) |
| `extraVolumes` / `extraVolumeMounts` | extra volumes; a `/tmp` `emptyDir` is always mounted regardless |

## Per-environment overrides

`argocd/envs/<env>/values.yaml` sets only what differs. Expected shape:

| Key | dev | staging | prod |
|---|---|---|---|
| `argoRollouts.enabled` | `false` | `true` | `true` |
| `replicaCount` / autoscaling range | small | medium | larger |
| `resources` | modest | medium | production-sized |
| `ingress.host` | `platform-api.dev.example.com` | `platform-api.staging.example.com` | `platform-api.example.com` |
| `image.tag` | CI-written | promoted by PR | promoted by PR |
| `pdb.minAvailable` | may be `0`/omitted | `1` | `50%` |

`example.com` hosts are placeholders.

## Why `appVersion` stays at `0.1.0`

The chart's `appVersion` tracks the *application release line*. The thing that actually
changes on every deploy is the **image tag** (the git SHA), which CI writes into the
environment values file and which surfaces on pods as `app.kubernetes.io/version`. Bumping
`appVersion` on every image would make `helm ls` and the chart release history misleading.
`appVersion` moves only on a real `platform-api` version change.

## Secrets

No secret values — real or placeholder — are committed. The chart's `externalsecret.yaml`
(gated `externalSecrets.enabled`) declares which keys the app needs and where they come
from; the External Secrets Operator materialises `platform-api-secrets`, which the pod
consumes with `envFrom`. `security/secrets/` has a standalone example and a SOPS note. See
[security.md](security.md).
