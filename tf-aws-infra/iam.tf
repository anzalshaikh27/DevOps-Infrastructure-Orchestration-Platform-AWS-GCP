# EC2 Role that allows EC2 instances to access S3
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "${var.vpc_name}-ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "rds.amazonaws.com"
          ]
        }
      }
    ]
  })


  tags = {
    Name        = "${var.vpc_name}-ec2-s3-access-role"
    Environment = var.environment
  }
}

# Policy for S3 bucket access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.vpc_name}-s3-access-policy"
  description = "Allow access to the application S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetObjectAcl"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.app_bucket.arn,
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Policy for RDS access
resource "aws_iam_policy" "rds_access_policy" {
  name        = "${var.vpc_name}-rds-access-policy"
  description = "Allow RDS operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds:CreateDBSubnetGroup",
          "rds:CreateDBParameterGroup",
          "rds:ModifyDBParameterGroup",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
          "rds:CreateDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:DeleteDBInstance",
          "rds:DeleteDBParameterGroup",
          "rds:DeleteDBSubnetGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Adding for CloudWatchAgentServerPolicy
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "${var.vpc_name}-cloudwatch-policy"
  description = "Allow access to CloudWatch for logging and metrics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ],
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      }
    ]
  })
}

# Policy for KMS key access
resource "aws_iam_policy" "kms_access_policy" {
  name        = "${var.vpc_name}-kms-access-policy"
  description = "Allow access to KMS keys for encryption/decryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Effect = "Allow"
        Resource = [
          aws_kms_key.ec2_key.arn,
          aws_kms_key.rds_key.arn,
          aws_kms_key.s3_key.arn,
          aws_kms_key.secrets_key.arn
        ]
      }
    ]
  })
}

# Policy for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "${var.vpc_name}-secrets-manager-policy"
  description = "Allow access to retrieve secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.db_password_secret.arn
        ]
      }
    ]
  })
}

# Attach KMS policy to the role
resource "aws_iam_role_policy_attachment" "kms_access_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.kms_access_policy.arn
}

# Attach Secrets Manager policy to the role
resource "aws_iam_role_policy_attachment" "secrets_manager_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}

# Attach CloudWatch policy to the role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

# Attach the S3 policy to the role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Attach the RDS policy to the role
resource "aws_iam_role_policy_attachment" "rds_access_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.rds_access_policy.arn
}

# Create an instance profile for the role
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "${var.vpc_name}-ec2-s3-profile"
  role = aws_iam_role.ec2_s3_access_role.name
}