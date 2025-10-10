# ============================================
# Tunefy Production Network Configuration
# For NEW AWS Account (Free Tier)
# ============================================

project   = "tunefy"
region    = "us-east-1"
env       = "prod"

# Availability Zones
azs       = ["us-east-1a", "us-east-1b", "us-east-1c"]

# VPC CIDR (different from dev to avoid conflicts)
vpc_cidr  = "10.30.0.0/16"

# NAT Gateway Strategy
# false = 1 NAT Gateway (cost optimization)
# true  = 1 NAT per AZ (HA, recommended for production)
nat_per_az = false  # Set to true for full HA

tags = {
  Owner       = "DevOps"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Project     = "Tunefy"
  CostCenter  = "Engineering"
}

