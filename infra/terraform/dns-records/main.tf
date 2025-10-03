# Route53 A record (Alias) for app.dev.tunefy.site -> ALB
resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = "app.dev.tunefy.site"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Route53 A record (Alias) for grafana.dev.tunefy.site -> ALB (mismo ALB por ahora)
resource "aws_route53_record" "grafana" {
  zone_id = var.hosted_zone_id
  name    = "grafana.dev.tunefy.site"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
