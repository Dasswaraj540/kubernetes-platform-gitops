# Module: `eks`

An EKS cluster for one environment, plus everything it needs to be usable:

- cluster IAM role with `AmazonEKSClusterPolicy` / `AmazonEKSVPCResourceController`,
- control-plane security group,
- control-plane audit/api/authenticator/scheduler/controllerManager logs to CloudWatch,
- **secrets envelope encryption** using the KMS key from the `kms` module,
- an IAM OIDC provider derived from the cluster issuer (the basis for IRSA),
- a managed node group in the private subnets with worker / CNI / ECR-read / SSM policies.

Cluster name is `platform-<env>-eks` — deliberately distinct from the `platform-<env>`
namespace so scripts and kubeconfig contexts never collide.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | — | e.g. `platform-dev` |
| `cluster_name` | string | — | e.g. `platform-dev-eks` |
| `kubernetes_version` | string | `1.31` | |
| `vpc_id` | string | — | from `module.vpc.vpc_id` |
| `private_subnet_ids` | list(string) | — | from `module.vpc.private_subnet_ids` |
| `public_subnet_ids` | list(string) | — | from `module.vpc.public_subnet_ids` |
| `kms_key_arn` | string | — | from `module.kms.key_arn` |
| `endpoint_public_access` | bool | `true` | |
| `public_access_cidrs` | list(string) | `["0.0.0.0/0"]` | tighten per environment |
| `enabled_cluster_log_types` | list(string) | all five | |
| `node_instance_types` | list(string) | `["t3.large"]` | |
| `node_desired_size` / `node_min_size` / `node_max_size` | number | `2` / `2` / `4` | |
| `node_disk_size` | number | `50` | GiB |
| `tags` | map(string) | `{}` | |

## Outputs

`cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data`,
`cluster_security_group_id`, `oidc_provider_arn`, `oidc_provider_url`, `node_group_role_arn`.
