# ── ACM Certificate (must be in us-east-1 for CloudFront) ────────────────────
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "portfolio" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-cert" }
}

# ── Look up existing Route 53 hosted zone ────────────────────────────────────
# Since domain is already registered in Route 53, we reference it
# rather than creating a new one.
data "aws_route53_zone" "portfolio" {
  name         = var.domain_name
  private_zone = false
}

# ── Automatic DNS validation for the ACM cert ────────────────────────────────
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.portfolio.domain_validation_options :
    dvo.domain_name => dvo
  }

  zone_id = data.aws_route53_zone.portfolio.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "portfolio" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.portfolio.arn
  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}

# ── DNS records pointing your domain at CloudFront ───────────────────────────
resource "aws_route53_record" "portfolio_apex" {
  zone_id = data.aws_route53_zone.portfolio.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "portfolio_www" {
  zone_id = data.aws_route53_zone.portfolio.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio.hosted_zone_id
    evaluate_target_health = false
  }
}
