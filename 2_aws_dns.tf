# Copyright IBM Corp. 2024, 2026

data "aws_route53_zone" "demo" {
  count = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  name  = var.public_hosted_zone
}

# Request a public certificate in ACM for the external NLB listener
resource "aws_acm_certificate" "public" {
  count             = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  domain_name       = "${var.demo_subdomain}.${var.public_hosted_zone}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Publish ACM DNS validation records in Route53
resource "aws_route53_record" "public_validation" {
  for_each = var.step_2 && var.public_hosted_zone != "" ? {
    for dvo in aws_acm_certificate.public[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  zone_id = data.aws_route53_zone.demo[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]

  allow_overwrite = true
}

# Complete ACM certificate validation
resource "aws_acm_certificate_validation" "public" {
  count                   = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.public[0].arn
  validation_record_fqdns = [for record in aws_route53_record.public_validation : record.fqdn]
}

# Map the public website DNS fully to the Kubernetes NGINX ingress Controller IPs
resource "aws_route53_record" "web_dns_record" {
  count   = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  zone_id = data.aws_route53_zone.demo[0].zone_id
  name    = "${var.demo_subdomain}.${var.public_hosted_zone}"
  type    = "A"
  ttl     = 300
  # Directly resolving the pre-allocated EIPs attached to the NLB!
  records = aws_eip.nginx_ingress[*].public_ip
}
