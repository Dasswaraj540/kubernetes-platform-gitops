# Architecture

This document is the detailed companion to the [README](../README.md) architecture section.
It records the canonical contract values first, then walks each layer.

## Canonical contract

Every file in the repository follows these names, ports, and versions. When a file disagrees
with this table, the file is the bug.

| Concern | Value |
|---|---|
| App / image / chart / release name | `platform-api` |
| Java package / Maven coordinates | `io.platform.api` / `io.platform:platform-api:0.1.0` |
| App + chart version (`appVersion`) | `0.1.0` (not bumped on image-only change) |
| Deployed image tag | 7-char git short SHA, written by CI into `argocd/envs/<env>/values.yaml` |
| Environments / namespaces | `dev`/`staging`/`prod` → `platform-dev`/`platform-staging`/`platform-prod` |
| EKS cluster name | `platform-<env>-eks` |
| Argo CD Application / AppProject | `platform-api-<env>` / `platform` |
| Argo CD `targetRevision` | `HEAD` |
| Default branch | `main` |
| Image reference | `ghcr.io/OWNER/platform-api` |
| Repo URL | `https://github.com/OWNER/kubernetes-platform-gitops.git` |
| HTTP port / management port | `8080` (`http`) / `8081` (`management`) |
| Probes + scrape target | `8081` only |
| Metrics path | `/actuator/prometheus` |
| Probe paths | `/actuator/health/liveness`, `/actuator/health/readiness` |
| Public API | `GET /api/v1/{health,info,items}` on `8080` |
| Chart path / env overrides | `helm/platform-api` / `argocd/envs/<env>/values.yaml` |
| Runtime / build base image | `eclipse-temurin:21-jre-jammy` / `maven:3.9-eclipse-temurin-21` |
| Non-root UID/GID | `10001` / `10001` |
| Build context / Dockerfile | `app/` / `docker/Dockerfile` |
| Ingress class | `nginx` (ALB = documented swap) |
| Rollout analysis Prometheus address | `http://prometheus-operated.monitoring.svc:9090` |

### Label set

| Label | Value |
|---|---|
| `app.kubernetes.io/name` | `platform-api` |
| `app.kubernetes.io/instance` | `platform-api-<env>` |
| `app.kubernetes.io/version` | image tag (git SHA) |
| `app.kubernetes.io/component` | `api` |
| `app.kubernetes.io/part-of` | `platform` |
| `app.kubernetes.io/managed-by` | `Helm` |

Selector subset (immutable): `app.kubernetes.io/name`, `app.kubernetes.io/instance`.

## Layer walk

### 1. Source and CI

The developer's push triggers CI (`ci/Jenkinsfile`, mirrored by
`.github/workflows/ci.yml`). CI produces one artifact — a container image tagged with the
7-character git short SHA — and one side effect — a commit that writes that tag into
`argocd/envs/dev/values.yaml`. CI never talks to a cluster. See [ci-cd.md](ci-cd.md).

### 2. Registry

`ghcr.io/OWNER/platform-api:<sha>`. Immutable tags: a SHA is built and pushed once. The
Terraform `ecr` module defines the AWS-native equivalent; switching is a one-line change to
`image.repository` plus registry auth in CI. See [terraform.md](terraform.md).

### 3. Desired state (this repository)

The Helm chart `helm/platform-api` is the single definition of every workload object. The
per-environment files `argocd/envs/<env>/values.yaml` carry only what differs between
environments. `helm/platform-api/values.schema.json` validates the merged result. See
[configuration.md](configuration.md).

### 4. Argo CD

The `platform` `AppProject` bounds the blast radius: one source repo, the `platform-*`
destination namespaces, and an explicit allow-list of resource kinds including the
`argoproj.io`, `monitoring.coreos.com`, and `external-secrets.io` CRDs.

Each `platform-api-<env>` `Application` is multi-source:

- source 1: the chart at `path: helm/platform-api`, `targetRevision: HEAD`
- source 2: `ref: values`, same repo, `targetRevision: HEAD`, providing
  `valueFiles: [$values/argocd/envs/<env>/values.yaml]`
- `source.helm.releaseName: platform-api` so rendered names never carry the environment

Sync policy: dev automated + selfHeal + prune; staging automated, no prune; prod manual.
See [gitops.md](gitops.md).

### 5. Workload

| Object | Source | Key points |
|---|---|---|
| `Deployment` | chart, `if not argoRollouts.enabled` | dev only; `RollingUpdate` `maxUnavailable: 0` |
| `Rollout` | chart, `if argoRollouts.enabled` | staging/prod; canary steps + analysis; no `spec.replicas` (HPA owns it) |
| `Service` `platform-api` | chart | ports `http`/`management`; stable service under canary |
| `Service` `platform-api-canary` | chart, `if argoRollouts.enabled` | canary traffic target |
| `Ingress` | chart | `ingressClassName: nginx`; per-env host; gated TLS |
| `ConfigMap` | chart | pod-template checksum annotation forces roll on change |
| `ServiceAccount` `platform-api` | chart | IRSA `eks.amazonaws.com/role-arn` annotation (empty default) |
| `Role` + `RoleBinding` | chart, `if rbac.create` | `get`/`list` on own ConfigMap only |
| `HorizontalPodAutoscaler` | chart, `if autoscaling.enabled` | CPU + memory; `scaleTargetRef` kind follows the toggle |
| `PodDisruptionBudget` | chart | `minAvailable` compatible with the canary step sizes |
| `NetworkPolicy` | chart | explicit allows over the `k8s/` default-deny |
| `ServiceMonitor` | chart, `if serviceMonitor.enabled` | scrapes `management` `/actuator/prometheus` |
| `PrometheusRule` | chart, `if prometheusRule.enabled` | the six alert rules |
| `AnalysisTemplate` `platform-api-success-rate` | chart, `if argoRollouts.enabled` | Prometheus success-rate query |
| `ExternalSecret` | chart, `if externalSecrets.enabled` | produces `platform-api-secrets` |

Bootstrap (in `k8s/`, applied before Argo CD owns the namespace): `Namespace` with PSA
`restricted`, `ResourceQuota`, `LimitRange`, baseline RBAC, default-deny `NetworkPolicy`.

### 6. Pod template

Container listens on 8080 (app) and 8081 (management). Probes and the Prometheus scrape hit
8081 only. Security context: non-root 10001, read-only root filesystem with a `/tmp`
`emptyDir`, no privilege escalation, all capabilities dropped, `seccomp: RuntimeDefault`.
Requests and limits always set. `liveness` / `readiness` / `startup` probes. Graceful
shutdown: `preStop` sleep + `terminationGracePeriodSeconds` aligned with the application's
`server.shutdown: graceful` phase timeout. `topologySpreadConstraints` across
`topology.kubernetes.io/zone` and `kubernetes.io/hostname`.

### 7. Observability

Prometheus scrapes 8081; Grafana and Alertmanager consume the data; the OpenTelemetry
Collector receives OTLP when the agent is enabled. See [observability.md](observability.md).

### 8. Substrate (Terraform)

`vpc` → `kms` → `ecr` → `eks` → `iam`, composed per environment under
`terraform/environments/<env>/`. See [terraform.md](terraform.md).

## Diagrams

The rendered flow diagrams live in the [README](../README.md#3-architecture). This document
stays text-first so it diffs cleanly.
