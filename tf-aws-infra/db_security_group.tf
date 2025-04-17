resource "aws_security_group" "database" {
  name        = "${var.vpc_name}-database-sg"
  description = "Security group for database instances"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL access from application security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
    description     = "PostgreSQL access from application"
  }

  # No direct egress rules - maximum restriction
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound traffic"
  }

  tags = {
    Name        = "${var.vpc_name}-database-sg"
    Environment = var.environment
  }
}