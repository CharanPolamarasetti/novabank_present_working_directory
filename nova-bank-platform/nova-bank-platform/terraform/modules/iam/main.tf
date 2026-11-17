variable "name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_issuer_host" {
  type = string
}

variable "secret_arns" {
  description = "Secrets External Secrets Operator may read."
  type        = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "ecr_repository_arns" {
  type = list(string)
}

variable "jenkins_trusted_principal_arns" {
  description = "Principals allowed to assume the Jenkins CI role (e.g. the Jenkins EC2 role)."
  type        = list(string)
  default     = []
}

data "aws_caller_identity" "current" {}

# ---------- IRSA role: External Secrets Operator (read-only on listed secrets)
data "aws_iam_policy_document" "eso_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eso" {
  statement {
    sid       = "ReadNovaBankSecrets"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = var.secret_arns
  }
  statement {
    sid       = "DecryptSecrets"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.name}-eso-irsa"
  assume_role_policy = data.aws_iam_policy_document.eso_assume.json
}

resource "aws_iam_role_policy" "eso" {
  name   = "read-secrets"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso.json
}

# ---------- Jenkins CI role: push to the project's ECR repos only
data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = length(var.jenkins_trusted_principal_arns) > 0 ? var.jenkins_trusted_principal_arns : ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

data "aws_iam_policy_document" "jenkins" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
    ]
    resources = var.ecr_repository_arns
  }
  statement {
    sid       = "EcrKms"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role" "jenkins" {
  name                 = "${var.name}-jenkins-ci"
  assume_role_policy   = data.aws_iam_policy_document.jenkins_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "jenkins" {
  name   = "ecr-push-only"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins.json
}

output "eso_role_arn" {
  value = aws_iam_role.eso.arn
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins.arn
}
