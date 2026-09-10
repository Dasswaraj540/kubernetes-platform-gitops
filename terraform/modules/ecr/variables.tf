variable "repository_name" {
  type        = string
  description = "ECR repository name."
  default     = "platform-api"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for encryption at rest."
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "force_delete" {
  type    = bool
  default = false
}

variable "untagged_expiry_days" {
  type    = number
  default = 14
}

variable "keep_last_tagged" {
  type    = number
  default = 20
}

variable "pull_principal_arns" {
  type        = list(string)
  description = "IAM principals granted pull access via the repository policy."
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
