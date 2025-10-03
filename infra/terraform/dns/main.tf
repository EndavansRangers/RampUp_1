variable "root_domain" {
  type        = string
  description = "Root domain name (e.g., tunefy.site)"
  default     = "tunefy.site"
}

# Hosted Zone pública para el dominio root
resource "aws_route53_zone" "root" {
  name    = var.root_domain
  comment = "Managed by Terraform - Tunefy DNS"

  tags = {
    Name        = var.root_domain
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Outputs para usar en otros módulos
output "hosted_zone_id" {
  value       = aws_route53_zone.root.zone_id
  description = "Route53 Hosted Zone ID for tunefy.site"
}

output "name_servers" {
  value       = aws_route53_zone.root.name_servers
  description = "Name servers to configure in Namecheap"
}

output "zone_arn" {
  value       = aws_route53_zone.root.arn
  description = "ARN of the hosted zone"
}
