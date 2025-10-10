#if we create apublic zone
resource "aws_route53_zone" "root" {
  count = var.create_zone ? 1 : 0
  name  = var.root_domain
  tags  = merge(local.common_tags, { Name = "${local.name}-zone" })
}

# If we create a private zone
# Commented out: Only needed if you have an existing zone
# data "aws_route53_zone" "root" {
#   count        = var.create_zone ? 0 : 1
#   name         = var.root_domain
#   private_zone = false
# }

locals {
  zone_id = var.create_zone ? aws_route53_zone.root[0].zone_id : null
}

output "route53_zone_id" {
  value = local.zone_id
}

# if we create the zone, we expose the NS to delegate the register
output "route53_name_servers" {
  value       = var.create_zone ? aws_route53_zone.root[0].name_servers : []
  description = "Si creaste la zona, apunta estos NS en tu registrador"
}
