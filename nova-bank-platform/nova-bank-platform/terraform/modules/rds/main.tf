variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "data_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  description = "SGs allowed to reach Postgres (EKS cluster SG)."
  type        = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "db_username" {
  type    = string
  default = "novabank"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  description = "true = HA standby in 2nd AZ (production). Costs ~2x; enable for the DR demo window."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "force_ssl" {
  description = "Enforce TLS. Set true once the services' JDBC URL carries sslmode=require (known follow-up)."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.data_subnet_ids
}

resource "aws_security_group" "db" {
  name        = "${var.name}-rds"
  description = "Postgres from EKS only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "from_eks" {
  for_each                     = toset(var.allowed_security_group_ids)
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = each.key
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Postgres from EKS nodes/pods"
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "postgres16"
  parameter {
    name  = "rds.force_ssl"
    value = var.force_ssl ? "1" : "0"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = "novabank"
  username = var.db_username
  password = var.db_password
  port     = 5432

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period         = var.backup_retention_days
  backup_window                   = "21:00-22:00"
  maintenance_window              = "sun:22:30-sun:23:30"
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.name}-final"
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = false
  apply_immediately               = true
}

output "endpoint_address" {
  value = aws_db_instance.this.address
}

output "instance_id" {
  value = aws_db_instance.this.identifier
}

output "instance_arn" {
  value = aws_db_instance.this.arn
}
