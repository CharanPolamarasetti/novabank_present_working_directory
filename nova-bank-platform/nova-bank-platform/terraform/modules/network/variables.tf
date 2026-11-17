variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  description = "Used for Kubernetes subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.16.0/22", "10.20.20.0/22"]
}

variable "data_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.32.0/24", "10.20.33.0/24"]
}

variable "single_nat_gateway" {
  description = "true = one NAT (cheap, lab). false = one NAT per AZ (production HA)."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "ECR/STS/Secrets Manager/Logs interface endpoints (private AWS API access)."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}
