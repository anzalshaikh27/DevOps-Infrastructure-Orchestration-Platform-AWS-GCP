# Generate a timestamp for unique KMS key names
resource "time_static" "kms_timestamp" {}

locals {
  timestamp_suffix = formatdate("YYYYMMDDhhmmss", time_static.kms_timestamp.rfc3339)
  account_id       = data.aws_caller_identity.current.account_id
}

# Get current AWS account identity
data "aws_caller_identity" "current" {}

# Common policy document for RDS, S3, and Secrets Manager KMS keys
data "aws_iam_policy_document" "common_kms_policy" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAccessForKeyAdministrators"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:user/aws-cli"]
    }
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:RotateKeyOnDemand"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowUseOfTheKey"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:user/aws-cli"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAttachmentOfPersistentResources"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:user/aws-cli"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

# EC2 specific policy document
data "aws_iam_policy_document" "ec2_kms_policy" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAccessForKeyAdministrators"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:user/aws-cli"]
    }
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:RotateKeyOnDemand"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowUseOfTheKey"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.account_id}:user/aws-cli",
        "arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAttachmentOfPersistentResources"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.account_id}:user/aws-cli",
        "arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

# Create KMS Key for EC2
resource "aws_kms_key" "ec2_key" {
  description             = "KMS key for EC2 instances - ${local.timestamp_suffix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 90
  policy                  = data.aws_iam_policy_document.ec2_kms_policy.json

  tags = {
    Name        = "${var.vpc_name}-ec2-kms-key-${local.timestamp_suffix}"
    Environment = var.environment
  }
}

# Create KMS Key for RDS
resource "aws_kms_key" "rds_key" {
  description             = "KMS key for RDS instances - ${local.timestamp_suffix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 90
  policy                  = data.aws_iam_policy_document.common_kms_policy.json

  tags = {
    Name        = "${var.vpc_name}-rds-kms-key-${local.timestamp_suffix}"
    Environment = var.environment
  }
}

# Create KMS Key for S3
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 buckets - ${local.timestamp_suffix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 90
  policy                  = data.aws_iam_policy_document.common_kms_policy.json

  tags = {
    Name        = "${var.vpc_name}-s3-kms-key-${local.timestamp_suffix}"
    Environment = var.environment
  }
}

# Create KMS Key for Secrets Manager
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for Secrets Manager - ${local.timestamp_suffix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 90
  policy                  = data.aws_iam_policy_document.common_kms_policy.json

  tags = {
    Name        = "${var.vpc_name}-secrets-kms-key-${local.timestamp_suffix}"
    Environment = var.environment
  }
}

# Create aliases for better identification
resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/${var.vpc_name}-ec2-key-${local.timestamp_suffix}"
  target_key_id = aws_kms_key.ec2_key.key_id
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/${var.vpc_name}-rds-key-${local.timestamp_suffix}"
  target_key_id = aws_kms_key.rds_key.key_id
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${var.vpc_name}-s3-key-${local.timestamp_suffix}"
  target_key_id = aws_kms_key.s3_key.key_id
}

resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/${var.vpc_name}-secrets-key-${local.timestamp_suffix}"
  target_key_id = aws_kms_key.secrets_key.key_id
}

# Output the KMS key ARNs for use in other resources
output "kms_key_ec2_arn" {
  description = "ARN of the KMS key for EC2 encryption"
  value       = aws_kms_key.ec2_key.arn
}

output "kms_key_rds_arn" {
  description = "ARN of the KMS key for RDS encryption"
  value       = aws_kms_key.rds_key.arn
}

output "kms_key_s3_arn" {
  description = "ARN of the KMS key for S3 encryption"
  value       = aws_kms_key.s3_key.arn
}

output "kms_key_secrets_arn" {
  description = "ARN of the KMS key for Secrets Manager"
  value       = aws_kms_key.secrets_key.arn
}