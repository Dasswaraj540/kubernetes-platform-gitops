# NetworkPolicy model

Two layers, read together.

## Layer 1 — namespace default-deny

`k8s/namespaces/platform-<env>.yaml` includes:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

With no `ingress`/`egress` rules, this denies all pod traffic in the namespace in both
directions. Nothing communicates until something re-opens a path.

## Layer 2 — the chart's per-workload allows

`helm/platform-api/templates/networkpolicy.yaml` (gated `networkPolicy.enabled`) selects the
`platform-api` pods and allows exactly:

| Direction | Peer | Port | Why |
|---|---|---|---|
| Ingress | namespace `networkPolicy.ingressControllerNamespace` (default `ingress-nginx`) | `http` (8080) | serve the public API via the Ingress |
| Ingress | namespace `networkPolicy.monitoringNamespace` (default `monitoring`) | `management` (8081) | Prometheus scrape |
| Egress | namespace `networkPolicy.dnsNamespace` (default `kube-system`) | 53/UDP, 53/TCP | DNS resolution |
| Egress | `networkPolicy.extraEgress` entries | as configured | e.g. the OTel Collector, downstream APIs |

Peers are matched with `namespaceSelector` on `kubernetes.io/metadata.name`, the label the
API server sets on every namespace.

## Consequences

- The app cannot reach arbitrary cluster or internet endpoints. If it needs to (a downstream
  service, the OTel Collector), add an explicit `networkPolicy.extraEgress` entry.
- If the ingress controller or Prometheus runs in a namespace with a different name, set
  `networkPolicy.ingressControllerNamespace` / `monitoringNamespace` per environment.
- Kube-DNS egress is always allowed; without it the pod cannot resolve any name and fails
  readiness.
