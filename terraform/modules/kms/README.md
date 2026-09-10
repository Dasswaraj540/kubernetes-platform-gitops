# Module: `kms`

One customer-managed KMS key per environment, with rotation enabled and an alias
(`alias/<name_prefix>`). Used for ECR encryption at rest and EKS secrets envelope
encryption; the same key backs the S3 remote-state bucket in the backend design.

The key policy always grants the account root full control (so the key is never orphaned),
then optionally adds administrator, IAM-principal user, and AWS service-principal statements
based on the input lists.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | — | e.g. `platform-dev` |
| `description` | string | `platform-api envelope encryption key` | key description |
| `deletion_window_in_days` | number | `30` | |
| `key_administrator_arns` | list(string) | `[]` | principals allowed to administer |
| `key_user_arns` | list(string) | `[]` | principals allowed encrypt/decrypt |
| `service_principals` | list(string) | `[]` | e.g. `["eks.amazonaws.com"]` |
| `tags` | map(string) | `{}` | |

## Outputs

`key_arn`, `key_id`, `alias_name`, `alias_arn`.
