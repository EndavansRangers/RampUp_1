# ============================================
# VPC Peering Accepter: Prod Account
# ============================================
# This file accepts VPC Peering from Dev account
# Run this in PROD account (038686090046)

# Variable for peering connection ID (from Dev account output)
variable "vpc_peering_connection_id" {
  type        = string
  description = "VPC Peering Connection ID from Dev account (get from Dev terraform output)"
}

variable "dev_vpc_cidr" {
  type        = string
  description = "Dev VPC CIDR block"
  default     = "10.20.0.0/16"  # Confirm this matches Dev VPC
}

# Accept the VPC Peering Connection
resource "aws_vpc_peering_connection_accepter" "prod_accept_dev" {
  vpc_peering_connection_id = var.vpc_peering_connection_id
  auto_accept               = true

  tags = {
    Name        = "tunefy-prod-accept-dev-peering"
    Environment = "prod"
    Project     = "Tunefy"
    ManagedBy   = "Terraform"
    Side        = "Accepter"
  }
}

# Add routes to Dev VPC in all Prod private route tables
resource "aws_route" "prod_to_dev" {
  for_each = aws_route_table.private
  
  route_table_id            = each.value.id
  destination_cidr_block    = var.dev_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.prod_accept_dev.id
}

# Outputs
output "peering_accepted" {
  value       = aws_vpc_peering_connection_accepter.prod_accept_dev.accept_status
  description = "VPC Peering acceptance status (should be 'active')"
}

output "routes_added_to_dev" {
  value       = length(aws_route.prod_to_dev)
  description = "Number of route tables updated in Prod to reach Dev"
}

output "octopus_connection_test" {
  value = <<-EOT
    Test connectivity from Tentacle to Octopus:
    1. SSH to Tentacle: ssh -J ubuntu@54.91.57.185 ubuntu@<TENTACLE_IP>
    2. Test connection: curl -v http://10.20.63.199:10943
    3. Should get HTTP response from Octopus
  EOT
  description = "Commands to test VPC peering connectivity"
}
