# Module: `vpc`

Creates the network substrate for one environment: a VPC, public and private subnets across
the given AZs, an internet gateway, NAT gateway(s), route tables, and VPC flow logs to
CloudWatch.

Subnets are tagged for Kubernetes load-balancer discovery
(`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`,
`kubernetes.io/cluster/<cluster_name>`).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | — | e.g. `platform-dev` |
| `cidr_block` | string | `10.0.0.0/16` | VPC CIDR |
| `azs` | list(string) | — | AZs to spread subnets across |
| `private_subnet_cidrs` | list(string) | — | one per AZ |
| `public_subnet_cidrs` | list(string) | — | one per AZ |
| `single_nat_gateway` | bool | `true` | one shared NAT vs one per AZ |
| `flow_log_retention_days` | number | `30` | CloudWatch retention |
| `cluster_name` | string | — | used only for subnet tags |
| `tags` | map(string) | `{}` | applied to every resource |

## Outputs

`vpc_id`, `vpc_cidr_block`, `private_subnet_ids`, `public_subnet_ids`, `nat_gateway_ids`.
