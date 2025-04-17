# Load Balancer Security Group
resource "aws_security_group" "load_balancer" {
  name        = "${var.vpc_name}-lb-sg"
  description = "Security group for the application load balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.vpc_name}-lb-sg"
    Environment = var.environment
  }
}

# Updated Application Security Group
resource "aws_security_group" "application" {
  name        = "${var.vpc_name}-application-sg"
  description = "Security group for web applications"
  vpc_id      = aws_vpc.main.id

  # Application port access from load balancer only
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
    description     = "Application port access from load balancer"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.vpc_name}-application-sg"
    Environment = var.environment
  }
}