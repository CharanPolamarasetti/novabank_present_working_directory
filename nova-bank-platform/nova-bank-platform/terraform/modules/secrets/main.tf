locals {
  envs = toset(var.environments)
}

resource "random_password" "db" {
  for_each = local.envs
  length   = 24
  special  = false
}

resource "random_password" "jwt" {
  for_each = local.envs
  length   = 64
  special  = false
}

resource "random_password" "grafana" {
  length  = 20
  special = false
}

# ---- DB credentials (consumed by External Secrets Operator + RDS)
resource "aws_secretsmanager_secret" "db" {
  for_each                = local.envs
  name                    = "${var.name_prefix}/${each.key}/db"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
  description             = "Nova Bank ${each.key} database credentials"
}

resource "aws_secretsmanager_secret_version" "db" {
  for_each  = local.envs
  secret_id = aws_secretsmanager_secret.db[each.key].id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db[each.key].result
    host     = var.db_hosts[each.key]
  })
}

# ---- JWT signing secret shared by customer-service (issuer) and account-service (verifier)
resource "aws_secretsmanager_secret" "jwt" {
  for_each                = local.envs
  name                    = "${var.name_prefix}/${each.key}/jwt"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "jwt" {
  for_each      = local.envs
  secret_id     = aws_secretsmanager_secret.jwt[each.key].id
  secret_string = jsonencode({ secret = random_password.jwt[each.key].result })
}

# ---- Grafana admin
resource "aws_secretsmanager_secret" "grafana" {
  name                    = "${var.name_prefix}/monitoring/grafana"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id     = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({ user = "admin", password = random_password.grafana.result })
}

# ---- Teams webhook: container only. Value is set manually so it never enters Terraform state.
resource "aws_secretsmanager_secret" "teams_webhook" {
  name                    = "${var.name_prefix}/prod/teams-webhook"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
  description             = "Teams Workflows webhook URL. Set with: aws secretsmanager put-secret-value"
}

output "db_passwords" {
  value     = { for k, p in random_password.db : k => p.result }
  sensitive = true
}

output "secret_arns" {
  value = concat(
    [for s in aws_secretsmanager_secret.db : s.arn],
    [for s in aws_secretsmanager_secret.jwt : s.arn],
    [aws_secretsmanager_secret.grafana.arn, aws_secretsmanager_secret.teams_webhook.arn],
  )
}

output "teams_webhook_secret_name" {
  value = aws_secretsmanager_secret.teams_webhook.name
}
