# Secret handling

Two supported approaches. Neither puts a plaintext secret in Git.

## Preferred: External Secrets Operator → AWS Secrets Manager

Secret values live in AWS Secrets Manager under `platform/<env>/platform-api`. The External
Secrets Operator, authenticated by the `platform-api` IRSA role, materialises them into a
Kubernetes Secret named `platform-api-secrets`, which the pod consumes with `envFrom`.

- Chart: `helm/platform-api/templates/externalsecret.yaml` (gated `externalSecrets.enabled`,
  default `false`). Keys are declared in `externalSecrets.data`.
- Standalone reference: `external-secrets-example.yaml` in this directory.
- Rotating a value in Secrets Manager propagates within `refreshInterval` (default 1h); the
  ConfigMap checksum does **not** cover the Secret, so restart the workload if the app reads
  env only at startup.

## Alternative: SOPS-encrypted manifests

When an operator has no external secret store, a `Secret` manifest can be committed
**encrypted** with [SOPS](https://github.com/getsops/sops) and a KMS key:

```bash
sops --encrypt --kms arn:aws:kms:AWS_REGION:AWS_ACCOUNT_ID:key/KEY_ID \
  --encrypted-regex '^(data|stringData)$' secret.yaml > secret.enc.yaml
```

Only `data` / `stringData` are encrypted; the rest stays diffable. Argo CD decrypts at sync
time with the `argocd-vault-plugin` or a KSOPS plugin. The KMS key would be the one from
`terraform/modules/kms`.

`.gitignore` blocks `*.decrypted.yaml` and bare `.env` files as a backstop.

## Never

- No secret values, real or placeholder-that-looks-real, in any tracked file.
- No secrets in ConfigMaps, container args, image layers, or CI logs.
- No `kubectl create secret` in a script that echoes the value.
