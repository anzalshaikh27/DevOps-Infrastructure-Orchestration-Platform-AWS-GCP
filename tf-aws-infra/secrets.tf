# Generate a random password for RDS
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_-."
}

# Store the database password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password_secret" {
  name                    = "${var.vpc_name}-db-password-${formatdate("YYYYMMDD", timestamp())}"
  description             = "RDS database password for ${var.vpc_name}"
  kms_key_id              = aws_kms_key.secrets_key.arn
  recovery_window_in_days = 0 # Set to 0 to force immediate deletion

  tags = {
    Name        = "${var.vpc_name}-db-password-secret"
    Environment = var.environment
  }
}

# Store the secret value
resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id = aws_secretsmanager_secret.db_password_secret.id
  secret_string = jsonencode({
    username             = var.db_username,
    password             = random_password.db_password.result,
    engine               = "postgres",
    host                 = aws_db_instance.postgres_db.address,
    port                 = 5432,
    dbname               = var.db_name,
    dbInstanceIdentifier = aws_db_instance.postgres_db.identifier
  })
}