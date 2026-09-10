variable "name_prefix" {
  type        = string
  description = "Name prefix, e.g. platform-dev."
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS IAM OIDC provider ARN, from module.eks.oidc_provider_arn."
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS OIDC issuer URL without scheme, from module.eks.oidc_provider_url."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the workload ServiceAccount, e.g. platform-dev."
}

variable "service_account_name" {
  type    = string
  default = "platform-api"
}

variable "secrets_manager_prefix" {
  type        = string
  description = "Secrets Manager name prefix the workload may read, e.g. platform/dev/platform-api."
}

variable "gha_oidc_enabled" {
  type    = bool
  default = false
}

variable "gha_repository" {
  type        = string
  description = "owner/repo granted the CI push role, e.g. OWNER/kubernetes-platform-gitops."
  default     = ""
}

variable "gha_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_arn" {
  type        = string
  description = "ECR repository ARN the CI role may push to."
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
