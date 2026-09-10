variable "name_prefix" {
  type        = string
  description = "Name prefix, e.g. platform-dev."
}

variable "description" {
  type        = string
  description = "Human-readable key description."
  default     = "platform-api envelope encryption key"
}

variable "deletion_window_in_days" {
  type    = number
  default = 30
}

variable "key_administrator_arns" {
  type        = list(string)
  description = "IAM principals allowed to administer the key."
  default     = []
}

variable "key_user_arns" {
  type        = list(string)
  description = "IAM principals allowed to use the key for encrypt/decrypt."
  default     = []
}

variable "service_principals" {
  type        = list(string)
  description = "AWS service principals granted use of the key, e.g. eks.amazonaws.com."
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
