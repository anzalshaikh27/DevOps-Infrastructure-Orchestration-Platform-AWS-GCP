# Create DB subnet group using private subnets
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.vpc_name}-db-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name        = "${var.vpc_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Create DB parameter group
resource "aws_db_parameter_group" "postgres_param_group" {
  name        = "${var.vpc_name}-postgres-params"
  family      = "postgres14"
  description = "Custom parameter group for PostgreSQL"

  # Example parameters - adjust as needed
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name        = "${var.vpc_name}-postgres-params"
    Environment = var.environment
  }
}

# Create RDS instance
resource "aws_db_instance" "postgres_db" {
  identifier               = "csye6225"
  engine                   = "postgres"
  engine_version           = "14"
  instance_class           = "db.t3.micro"
  allocated_storage        = 20
  storage_type             = "gp2"
  db_name                  = var.db_name
  username                 = var.db_username
  password                 = random_password.db_password.result
  db_subnet_group_name     = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids   = [aws_security_group.database.id]
  parameter_group_name     = aws_db_parameter_group.postgres_param_group.name
  publicly_accessible      = false
  multi_az                 = false
  skip_final_snapshot      = true
  delete_automated_backups = true
  apply_immediately        = true

  # Associate the IAM role with RDS
  iam_database_authentication_enabled = true

  # Associate the specific role
  domain_iam_role_name = aws_iam_role.ec2_s3_access_role.name

  # Encryption settings
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds_key.arn

  tags = {
    Name        = "${var.vpc_name}-postgres-db"
    Environment = var.environment
  }
}

# Create the association between RDS instance and IAM role
resource "aws_db_instance_role_association" "rds_role_association" {
  db_instance_identifier = aws_db_instance.postgres_db.identifier
  feature_name           = "s3Import"
  role_arn               = aws_iam_role.ec2_s3_access_role.arn
}

# User data for EC2 instance
locals {
  user_data = <<-EOF
#!/bin/bash
# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWAGENTCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "csye6225"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/webapp/application.log",
            "log_group_name": "${var.vpc_name}-application-logs",
            "log_stream_name": "{instance_id}-application",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/webapp/error.log",
            "log_group_name": "${var.vpc_name}-error-logs",
            "log_stream_name": "{instance_id}-error",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "WebAppMetrics",
    "metrics_collected": {
      "statsd": {
        "service_address": ":8125",
        "metrics_collection_interval": 60,
        "metrics_aggregation_interval": 60
      },
      "cpu": {
        "resources": ["*"],
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "resources": ["/"],
        "measurement": ["used_percent", "inodes_free"]
      },
      "netstat": {
        "measurement": ["tcp_established", "tcp_time_wait"]
      }
    }
  }
}
CWAGENTCONFIG

echo "Setting up environment variables for the application"

# Ensure jq is installed
apt-get update
apt-get install -y jq

# Use AWS CLI to get DB credentials from Secrets Manager
if [ -x "$(command -v aws)" ]; then
  echo "Retrieving DB credentials from AWS Secrets Manager"
  
  # Get the secret
  SECRET=$(aws secretsmanager get-secret-value --secret-id ${var.vpc_name}-db-password --region ${var.region} --query SecretString --output text)
  
  # Parse JSON
  DB_USERNAME=$(echo $SECRET | jq -r '.username')
  DB_PASSWORD=$(echo $SECRET | jq -r '.password')
  DB_NAME=$(echo $SECRET | jq -r '.dbname')
  DB_HOST=$(echo $SECRET | jq -r '.host')
  
  # Create environment file
  cat > /opt/app/webapp/.env << ENVFILE
DATABASE_URL=postgres://$DB_USERNAME:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME
PORT=${var.app_port}
S3_BUCKET=${aws_s3_bucket.app_bucket.bucket}
ENVFILE
else
  echo "AWS CLI not found, using direct values"
  
  # Create environment file
  cat > /opt/app/webapp/.env << ENVFILE
DATABASE_URL=postgres://${var.db_username}:${random_password.db_password.result}@${aws_db_instance.postgres_db.address}:5432/${var.db_name}
PORT=${var.app_port}
S3_BUCKET=${aws_s3_bucket.app_bucket.bucket}
ENVFILE
fi

# Set permissions
chmod 600 /opt/app/webapp/.env
chown csye6225:csye6225 /opt/app/webapp/.env

# Ensure log directory exists
mkdir -p /var/log/webapp
chown -R csye6225:csye6225 /var/log/webapp
chmod 755 /var/log/webapp

# Start/restart the CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

# Restart application service
systemctl restart csye6225.service
EOF
}