variable "root_domain" {
  type        = string
  description = "Root domain name"
  default     = "tunefy.site"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 Hosted Zone ID"
  default     = "Z08442723HGVVHTX7RMST"
}

# 1) Certificado ACM para *.dev.tunefy.site
resource "aws_acm_certificate" "dev" {
  domain_name               = "*.dev.${var.root_domain}"
  validation_method         = "DNS"
  subject_alternative_names = ["dev.${var.root_domain}"]
  
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "wildcard-dev-tunefy-site"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# 2) Registros de validación DNS (DNS-01)
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.dev.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
  allow_overwrite = true
}

# 3) Esperar validación completa
resource "aws_acm_certificate_validation" "dev" {
  certificate_arn         = aws_acm_certificate.dev.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}

# Outputs
output "acm_cert_arn_dev" {
  value       = aws_acm_certificate.dev.arn
  description = "ARN del certificado ACM para *.dev.tunefy.site"
}

output "certificate_domain" {
  value       = aws_acm_certificate.dev.domain_name
  description = "Dominio del certificado"
}

output "certificate_status" {
  value       = aws_acm_certificate.dev.status
  description = "Estado del certificado"
}
