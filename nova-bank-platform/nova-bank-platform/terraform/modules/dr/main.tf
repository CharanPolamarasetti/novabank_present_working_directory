variable "name" {
  type = string
}

variable "dr_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "force_destroy" {
  type    = bool
  default = true
}

# Provider aliases are supplied by the caller: aws (primary) and aws.dr (DR region).
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

data "aws_caller_identity" "current" {}

# ---------- Backup bucket (primary) replicating to the DR region
resource "aws_s3_bucket" "dr" {
  provider      = aws.dr
  bucket        = "${var.name}-backup-dr-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_versioning" "dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "primary" {
  bucket        = "${var.name}-backup-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "repl_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "repl" {
  statement {
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.primary.arn]
  }
  statement {
    actions   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.primary.arn}/*"]
  }
  statement {
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
    resources = ["${aws_s3_bucket.dr.arn}/*"]
  }
}

resource "aws_iam_role" "repl" {
  name               = "${var.name}-s3-replication"
  assume_role_policy = data.aws_iam_policy_document.repl_assume.json
}

resource "aws_iam_role_policy" "repl" {
  name   = "replicate"
  role   = aws_iam_role.repl.id
  policy = data.aws_iam_policy_document.repl.json
}

resource "aws_s3_bucket_replication_configuration" "this" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.repl.arn
  rule {
    id     = "all-to-dr"
    status = "Enabled"
    filter {}
    delete_marker_replication {
      status = "Enabled"
    }
    destination {
      bucket        = aws_s3_bucket.dr.arn
      storage_class = "STANDARD_IA"
    }
  }
  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.dr]
}

output "primary_bucket" {
  value = aws_s3_bucket.primary.id
}

output "dr_bucket" {
  value = aws_s3_bucket.dr.id
}
