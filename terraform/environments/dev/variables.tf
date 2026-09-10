variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "owner" {
  type        = string
  description = "Value for the Owner tag."
  default     = "platform-team"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/20", "10.10.16.0/20", "10.10.32.0/20"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.128.0/24", "10.10.129.0/24", "10.10.130.0/24"]
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "gha_oidc_enabled" {
  type    = bool
  default = false
}

variable "gha_repository" {
  type    = string
  default = "OWNER/kubernetes-platform-gitops"
}
