# Create ACM certificate for dev environment if certificate ARN is not provided
resource "aws_acm_certificate" "cert" {
  count             = var.environment == "dev" && var.acm_certificate_arn == "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.vpc_name}-certificate"
    Environment = var.environment
  }
}

# Create validation DNS records
resource "aws_route53_record" "cert_validation" {
  for_each = var.environment == "dev" && var.acm_certificate_arn == "" ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

# Validate the certificate
resource "aws_acm_certificate_validation" "cert" {
  count                   = var.environment == "dev" && var.acm_certificate_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}