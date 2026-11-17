variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "allow_cloudtrail" {
  description = "Add the key-policy statement CloudTrail needs to encrypt its logs."
  type        = bool
  default     = false
}

variable "deletion_window_in_days" {
  type    = number
  default = 7
}
