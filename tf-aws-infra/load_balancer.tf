# Create Target Group for the Application
resource "aws_lb_target_group" "app_target_group" {
  name     = "${var.vpc_name}-target-group"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/healthz"
    port                = var.app_port
    protocol            = "HTTP"
    interval            = 150
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "${var.vpc_name}-target-group"
    Environment = var.environment
  }
}

# Create Application Load Balancer
resource "aws_lb" "app_load_balancer" {
  name               = "${var.vpc_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "${var.vpc_name}-alb"
    Environment = var.environment
  }
}

# Create HTTPS Listener
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (
    var.environment == "dev" ? aws_acm_certificate.cert[0].arn : null
  )

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }

  depends_on = [
    aws_acm_certificate_validation.cert
  ]
}