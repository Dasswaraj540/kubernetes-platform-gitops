# Terraform — AWS substrate

Modular Terraform for the AWS layer the platform runs on. No credentials, account IDs, or
account-numbered ARNs are in the repository. `terraform init` uses local state until you
configure the backend (see "Remote state design" below).

## Layout

```
modules/
  vpc/   VPC, public/private subnets per AZ, IGW, NAT, route tables, flow logs
  kms/   customer-managed KMS key + alias (rotation on)
  ecr/   platform-api repository: immutable tags, scan-on-push, KMS, lifecycle policy
  eks/   EKS cluster (secrets envelope encryption via KMS), OIDC provider, managed node group
  iam/   platform-api IRSA role; optional GitHub Actions OIDC push role
environments/
  dev/  staging/  prod/
    versions.tf            provider + version constraints
    backend.tf.example     S3 remote-state design (copy to backend.tf and fill in)
    variables.tf           per-environment defaults
    main.tf                provider default_tags, locals, module wiring (identical across envs)
    outputs.tf             cluster name/endpoint, OIDC ARN, ECR URL, KMS ARN, IRSA ARN
    terraform.tfvars.example
```

`main.tf`, `versions.tf`, and `outputs.tf` are identical in all three environment
directories; only `variables.tf` defaults, the state `key`, and the tfvars example differ.
`single_nat_gateway` is derived (`var.environment != "prod"`), so prod gets one NAT per AZ.

## Module dependency order

```
vpc ──► eks ──► iam
kms ──► ecr
kms ──────────► eks (secrets encryption)
ecr ──────────► iam (CI push policy target)
```

Terraform resolves this from the `module.*` references in `main.tf`.

## Remote state design

State is per environment. `backend.tf.example` describes an S3 + DynamoDB backend:

| Setting | Value |
|---|---|
| `bucket` | one versioned, SSE-KMS, private S3 bucket for all environments |
| `key` | `platform/<env>/terraform.tfstate` — one object per environment |
| `dynamodb_table` | `platform-tfstate-locks` — state locking |
| `encrypt` | `true` |
| `kms_key_id` | `alias/platform-tfstate` — a key created out of band, before the first apply |

The state bucket and lock table are bootstrap infrastructure: create them once (manually or
with a tiny separate Terraform config) before `terraform init` in any environment. To wire
it up: `cp backend.tf.example backend.tf`, set the bucket suffix, then `terraform init`.

## Tagging

`main.tf` builds `local.tags` and passes it to the provider `default_tags` and to every
module:

| Tag | Source |
|---|---|
| `Project` | `kubernetes-platform-gitops` |
| `Environment` | `var.environment` |
| `ManagedBy` | `terraform` |
| `Owner` | `var.owner` |

Modules add a `Name` tag per resource.

## Encryption touchpoints

| What | How |
|---|---|
| ECR images at rest | `aws_ecr_repository.encryption_configuration` → KMS key |
| EKS Kubernetes secrets | `aws_eks_cluster.encryption_config` (`resources = ["secrets"]`) → KMS key |
| S3 remote state | bucket SSE-KMS + `encrypt = true` in the backend |
| EBS on nodes | account-level EBS encryption-by-default is assumed; enable it in the target account |

## Least privilege

- The `platform-api` IRSA role trusts exactly `system:serviceaccount:platform-<env>:platform-api`
  and can read only `secretsmanager:...:secret:platform/<env>/platform-api*`.
- The optional GitHub Actions role trusts one repo + branch and can push to one ECR
  repository ARN.
- No `*:*` policies; managed policies are limited to the AWS-required EKS set.

## Running it

See [`docs/deployment.md`](../docs/deployment.md). In short, per environment:
`terraform init` → `terraform plan -var-file=terraform.tfvars` → `terraform apply`, `dev`
first. Then take `ecr_repository_url` and `platform_api_role_arn` from the outputs into the
Helm values.

## Community modules

These modules are intentionally thin and readable. A production build would likely replace
`vpc` and `eks` with `terraform-aws-modules/vpc/aws` and `terraform-aws-modules/eks/aws`,
which cover far more edge cases; the surrounding wiring and outputs would stay the same.
