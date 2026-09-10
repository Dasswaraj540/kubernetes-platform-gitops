# Module: `ecr`

One ECR repository for the `platform-api` image, with:

- immutable tags (a git SHA is pushed once and never moved),
- scan-on-push,
- KMS encryption at rest (key from the `kms` module),
- a lifecycle policy that expires untagged images and keeps only the most recent tagged ones,
- an optional repository policy granting pull to named principals.

`repository_url` replaces `ghcr.io/OWNER/platform-api` in `helm/platform-api/values.yaml`
when running on ECR. The default pipelines publish to GHCR; the ECR path is opt-in — see
[`docs/deployment.md`](../../../docs/deployment.md).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `repository_name` | string | `platform-api` | |
| `kms_key_arn` | string | — | from `module.kms.key_arn` |
| `image_tag_mutability` | string | `IMMUTABLE` | |
| `scan_on_push` | bool | `true` | |
| `force_delete` | bool | `false` | |
| `untagged_expiry_days` | number | `14` | |
| `keep_last_tagged` | number | `20` | |
| `pull_principal_arns` | list(string) | `[]` | principals granted pull |
| `tags` | map(string) | `{}` | |

## Outputs

`repository_url`, `repository_arn`, `repository_name`.
