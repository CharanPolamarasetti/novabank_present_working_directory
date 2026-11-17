variable "name" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "rds_instance_id" {
  type = string
}

resource "aws_sns_topic" "alerts" {
  # Not CMK-encrypted: CloudWatch/EventBridge/Budgets cannot publish to a CMK topic without extra key grants.
  name = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  rds_dim = { DBInstanceIdentifier = var.rds_instance_id }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = local.rds_dim
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name}-rds-free-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = local.rds_dim
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648 # 2 GiB
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.name}-rds-connections-high"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = local.rds_dim
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 60
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ---- Security signal: root account usage
resource "aws_cloudwatch_event_rule" "root_login" {
  name = "${var.name}-root-console-login"
  event_pattern = jsonencode({
    "detail-type" = ["AWS Console Sign In via CloudTrail"]
    detail        = { userIdentity = { type = ["Root"] } }
  })
}

resource "aws_cloudwatch_event_target" "root_login" {
  rule = aws_cloudwatch_event_rule.root_login.name
  arn  = aws_sns_topic.alerts.arn
}

# ---- GuardDuty HIGH/CRITICAL findings -> SNS
resource "aws_cloudwatch_event_rule" "guardduty" {
  name = "${var.name}-guardduty-high"
  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail        = { severity = [{ numeric = [">=", 7] }] }
  })
}

resource "aws_cloudwatch_event_target" "guardduty" {
  rule = aws_cloudwatch_event_rule.guardduty.name
  arn  = aws_sns_topic.alerts.arn
}

# EventBridge must be allowed to publish to the topic.
data "aws_iam_policy_document" "sns" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "cloudwatch.amazonaws.com", "budgets.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns.json
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
