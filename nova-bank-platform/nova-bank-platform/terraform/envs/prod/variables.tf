variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "dr_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "name" {
  type    = string
  default = "novabank-prod"
}

variable "azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "admin_ip_cidr" {
  description = "Your public IP as x.x.x.x/32 (EKS API + SSH allow-list)."
  type        = string
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs that get cluster-admin on EKS."
  type        = list(string)
}

variable "alert_email" {
  type = string
}

variable "monthly_budget_usd" {
  type    = number
  default = 60
}

variable "rds_multi_az" {
  description = "Enable for the DR demo; disable to save cost afterwards."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Cost trade-off: one NAT for the lab. Set false for per-AZ NAT in real production."
  type        = bool
  default     = true
}
