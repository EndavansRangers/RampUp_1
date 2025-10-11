# ============================================
# Tunefy Production Platform Configuration
# For NEW AWS Account (Free Tier)
# ============================================

project     = "tunefy"
region      = "us-east-1"
env         = "prod"

# ECR Repositories (will create: tunefy-frontend-prod, tunefy-backend-prod)
repos       = ["tunefy-frontend", "tunefy-backend"]

# Route53 Domain Configuration
# Set create_zone = true if you want Terraform to create the hosted zone
# Set create_zone = false if the domain is managed elsewhere or you don't have one
root_domain = "tunefy-prod.local"  # CHANGE THIS to your domain
create_zone = false                # Set to true if you want Terraform to manage DNS

tags = {
  Owner       = "DevOps"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Project     = "Tunefy"
  CostCenter  = "Engineering"
}

