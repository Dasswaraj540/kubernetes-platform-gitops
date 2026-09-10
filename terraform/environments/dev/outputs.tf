output "vpc_id" {
  description = "VPC id."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet ids."
  value       = module.vpc.private_subnet_ids
}

output "kms_key_arn" {
  description = "KMS key ARN."
  value       = module.kms.key_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL to substitute for the committed GHCR image reference."
  value       = module.ecr.repository_url
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN."
  value       = module.eks.oidc_provider_arn
}

output "platform_api_role_arn" {
  description = "IRSA role ARN for the platform-api ServiceAccount annotation."
  value       = module.iam.platform_api_role_arn
}

output "gha_oidc_role_arn" {
  description = "GitHub Actions OIDC role ARN, empty unless gha_oidc_enabled."
  value       = module.iam.gha_oidc_role_arn
}
