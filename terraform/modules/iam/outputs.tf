output "platform_api_role_arn" {
  description = "IRSA role ARN to annotate on the platform-api ServiceAccount."
  value       = aws_iam_role.platform_api.arn
}

output "platform_api_role_name" {
  description = "IRSA role name."
  value       = aws_iam_role.platform_api.name
}

output "gha_oidc_role_arn" {
  description = "GitHub Actions OIDC role ARN, or empty when gha_oidc_enabled is false."
  value       = var.gha_oidc_enabled ? aws_iam_role.gha[0].arn : ""
}
