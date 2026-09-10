# Progressive delivery with Argo Rollouts

`staging` and `prod` deploy `platform-api` as an Argo `Rollout` with a canary strategy. `dev`
stays a plain `Deployment` for fast feedback. The switch is the chart value
`argoRollouts.enabled`, set per environment in `argocd/envs/<env>/values.yaml`.

The Rollout, its canary/stable Services, the nginx traffic-routing wiring, and the
`AnalysisTemplate` are all rendered by the Helm chart at
[`helm/platform-api`](../helm/platform-api). This directory is documentation plus one
standalone example.

## How a canary rolls out

1. A new image tag lands in `argocd/envs/<env>/values.yaml`. Argo CD syncs; the Rollout sees
   a new pod template.
2. The Rollout brings up a canary ReplicaSet and points `platform-api-canary` at it.
3. Traffic shifts in steps. Chart default (`staging`): 20% → 50% → 80% with pauses between.
   `prod` uses smaller steps (10/25/50/75) and longer pauses — see
   `argocd/envs/prod/values.yaml`.
4. From step 2 onward a background `AnalysisRun` queries Prometheus for the canary's
   success rate:

   ```
   sum(rate(http_server_requests_seconds_count{namespace="<ns>",service="platform-api-canary",status!~"5.."}[2m]))
   /
   sum(rate(http_server_requests_seconds_count{namespace="<ns>",service="platform-api-canary"}[2m]))
   ```

   It must stay at or above `argoRollouts.analysis.successRateThreshold` (default `0.95`).
5. If analysis passes every step, the canary is **promoted**: it becomes the stable
   ReplicaSet and `platform-api` points at it.
6. If analysis fails (`failureLimit` exceeded), the Rollout **aborts**: traffic returns to
   the stable ReplicaSet and the canary scales to zero.

## Operating a rollout

```bash
kubectl argo rollouts -n platform-staging get rollout platform-api --watch

kubectl argo rollouts -n platform-staging promote platform-api
kubectl argo rollouts -n platform-staging promote platform-api --full

kubectl argo rollouts -n platform-staging abort platform-api
kubectl argo rollouts -n platform-staging undo platform-api

kubectl argo rollouts -n platform-staging get rollout platform-api -o yaml | \
  yq '.status.canary'
```

Promotion between environments is a **git** action: a reviewer copies the tested image tag
from `argocd/envs/staging/values.yaml` into `argocd/envs/prod/values.yaml` in a pull request.
See [`docs/gitops.md`](../docs/gitops.md).

## `example-rollout.yaml`

`example-rollout.yaml` is a self-contained copy of the rendered Rollout
(`platform.io/illustrative: "true"`) for reading the resource shape without Helm. Delivery
uses the chart; this file is not referenced by any Argo CD Application.
