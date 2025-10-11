# ============================================
# VPC Peering: Dev Account → Prod Account
# ============================================
# This file creates VPC Peering from Dev to Prod
# Run this in DEV account (638325785916)

# Data source for Dev VPC
data "aws_vpc" "dev" {
  id = var.dev_vpc_id  # vpc-0ac1ff8ba92cbf0f4
}

# Get route table IDs from Dev VPC
data "aws_route_tables" "dev_private" {
  vpc_id = data.aws_vpc.dev.id

  filter {
    name   = "tag:Name"
    values = ["*private*"]  # Adjust filter as needed
  }
}

# VPC Peering Connection Request (from Dev to Prod)
resource "aws_vpc_peering_connection" "dev_to_prod" {
  vpc_id        = data.aws_vpc.dev.id
  peer_vpc_id   = var.prod_vpc_id
  peer_owner_id = var.prod_account_id
  peer_region   = var.region
  
  tags = {
    Name        = "tunefy-dev-to-prod-peering"
    Environment = "dev"
    Project     = "Tunefy"
    ManagedBy   = "Terraform"
    Side        = "Requester"
  }
}

# Add routes to Prod VPC CIDR in all Dev private route tables
resource "aws_route" "dev_to_prod" {
  for_each = toset(data.aws_route_tables.dev_private.ids)
  
  route_table_id            = each.value
  destination_cidr_block    = var.prod_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_prod.id
}

# Update Security Group for Octopus (allow traffic from Prod)
# Add ingress rule to CI/CD SG (allow Tentacle from Prod)
resource "aws_security_group_rule" "octopus_allow_prod_tentacle" {
  type              = "ingress"
  from_port         = 10943
  to_port           = 10943
  protocol          = "tcp"
  cidr_blocks       = [var.prod_vpc_cidr]
  description       = "Allow Octopus Tentacle polling from Prod VPC"
  security_group_id = "sg-0df61e002efefe332"  # CI/CD Security Group
}

# Outputs
output "vpc_peering_id" {
  value       = aws_vpc_peering_connection.dev_to_prod.id
  description = "VPC Peering Connection ID (use this in Prod account)"
}

output "vpc_peering_status" {
  value       = aws_vpc_peering_connection.dev_to_prod.accept_status
  description = "VPC Peering status (should be 'pending-acceptance')"
}

output "dev_vpc_id" {
  value       = data.aws_vpc.dev.id
  description = "Dev VPC ID"
}

output "dev_vpc_cidr" {
  value       = data.aws_vpc.dev.cidr_block
  description = "Dev VPC CIDR"
}

output "octopus_private_ip" {
  value       = "10.20.63.199"
  description = "Octopus server private IP"
}

output "octopus_url_for_prod" {
  value       = "http://10.20.63.199:10943"
  description = "Octopus URL to use in Prod terraform.tfvars"
}

output "routes_added" {
  value       = length(data.aws_route_tables.dev_private.ids)
  description = "Number of route tables updated in Dev"
}
