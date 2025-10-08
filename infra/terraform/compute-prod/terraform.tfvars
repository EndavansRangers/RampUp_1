# Tunefy Production - Terraform Variables
# Generated: 2025-10-06

project = "tunefy"
region  = "us-east-1"
env     = "prod"

# VPC and Subnets
vpc_id = "vpc-020517f941f39faeb"

# Public Subnets (MapPublicIpOnLaunch=True)
public_subnet_ids = [
  "subnet-0e5eb4fb97b06e06d",  # us-east-1a - 10.20.0.0/20
  "subnet-04fd1e98e18081cc8",  # us-east-1b - 10.20.16.0/20
  "subnet-0bf336d6766af9fa1"   # us-east-1c - 10.20.32.0/20
]

# Private Subnets (MapPublicIpOnLaunch=False)
private_subnet_ids = [
  "subnet-00a4495a3cbe62cdd",  # us-east-1a - 10.20.48.0/20
  "subnet-02515cf41ddd44699",  # us-east-1b - 10.20.64.0/20
  "subnet-05f8876a5c9a7d02a"   # us-east-1c - 10.20.80.0/20
]

# SSH Key
key_name = "tunefy-dev-key"

# Your Public IP for SSH access to bastion
allowed_ssh_cidr = "165.1.173.37/32"

# Kubernetes Cluster
cluster_name = "tunefy-prod"

# Instance Types (No Free Tier - using t3.large)
cp_instance_type      = "t3.large"   # Control planes with more resources
wk_instance_type      = "t3.large"   # Workers with more resources
bastion_instance_type = "t3.micro"   # Bastion can stay small

# IAM Instance Profile (from platform module)
# This should exist from your previous setup
nodes_instance_profile_name = "tunefy-prod-nodes"

# Additional Tags (Shared account - identify your project)
tags = {
  owner      = "david.cifuentes"
  project    = "tunefy-david.cifuentes"
  Team       = "DevOps"
  CostCenter = "Engineering"
  Terraform  = "true"
}
