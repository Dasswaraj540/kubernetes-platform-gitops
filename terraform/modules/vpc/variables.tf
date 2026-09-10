variable "name_prefix" {
  type        = string
  description = "Name prefix for all resources, e.g. platform-dev."
}

variable "cidr_block" {
  type        = string
  description = "Primary IPv4 CIDR for the VPC."
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to place subnets in."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "One private subnet CIDR per availability zone."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "One public subnet CIDR per availability zone."
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use one shared NAT gateway instead of one per AZ."
  default     = true
}

variable "flow_log_retention_days" {
  type        = number
  description = "CloudWatch retention for VPC flow logs."
  default     = 30
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name used to tag subnets for load-balancer discovery."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
