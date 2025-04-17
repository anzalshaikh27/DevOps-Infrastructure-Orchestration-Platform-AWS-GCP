# cloudwatch.tf
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "${var.vpc_name}-application-logs"
  retention_in_days = 30

  tags = {
    Name        = "${var.vpc_name}-application-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "error_logs" {
  name              = "${var.vpc_name}-error-logs"
  retention_in_days = 30

  tags = {
    Name        = "${var.vpc_name}-error-logs"
    Environment = var.environment
  }
}