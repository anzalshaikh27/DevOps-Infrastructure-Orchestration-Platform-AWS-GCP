locals {
  domain_name = "anzalshaikh.me"
  subdomain   = "${var.environment}.${local.domain_name}"
}

# Create A record for the subdomain pointing to the load balancer
resource "aws_route53_record" "subdomain" {
  zone_id = var.hosted_zone_id
  name    = local.subdomain
  type    = "A"

  alias {
    name                   = aws_lb.app_load_balancer.dns_name
    zone_id                = aws_lb.app_load_balancer.zone_id
    evaluate_target_health = true
  }
}