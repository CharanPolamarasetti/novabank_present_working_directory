variable "name_prefix" {
  description = "Repository namespace, e.g. novabank-prod -> novabank-prod/account-service"
  type        = string
}

variable "repositories" {
  type    = list(string)
  default = ["account-service", "customer-service", "frontend"]
}

variable "kms_key_arn" {
  type = string
}

variable "retention_count" {
  description = "Keep the newest N images per repository."
  type        = number
  default     = 20
}

variable "untagged_expire_days" {
  type    = number
  default = 7
}

variable "force_delete" {
  description = "Allow destroy with images present (lab)."
  type        = bool
  default     = true
}
