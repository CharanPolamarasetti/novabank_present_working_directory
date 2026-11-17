variable "name_prefix" {
  type    = string
  default = "novabank"
}

variable "environments" {
  type    = list(string)
  default = ["dev", "prod"]
}

variable "kms_key_arn" {
  type = string
}

variable "db_username" {
  type    = string
  default = "novabank"
}

variable "db_hosts" {
  description = "DB host per environment. dev = in-cluster Postgres service; prod = RDS endpoint (wired from the rds module)."
  type        = map(string)
}

variable "recovery_window_in_days" {
  description = "0 = delete immediately (lab, allows clean re-apply). Use 7-30 in real production."
  type        = number
  default     = 0
}
