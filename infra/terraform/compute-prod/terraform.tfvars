# Tunefy Production - Terraform Variables
# Generated: 2025-10-06

project = "tunefy"
region  = "us-east-1"
env     = "prod"

# VPC and Subnets (from network module output)
vpc_id = "vpc-0976ad85d907cbb75"

# Public Subnets (MapPublicIpOnLaunch=True)
public_subnet_ids = [
  "subnet-03c0d7eda310dae73",  # us-east-1a - 10.30.0.0/20
  "subnet-094c8128fc8c54209",  # us-east-1b - 10.30.16.0/20
  "subnet-0acb364dbc2a252a9"   # us-east-1c - 10.30.32.0/20
]

# Private Subnets (MapPublicIpOnLaunch=False)
private_subnet_ids = [
  "subnet-0a683b0f4793af52c",  # us-east-1a - 10.30.48.0/20
  "subnet-00cdf0e2b15d2cf08",  # us-east-1b - 10.30.64.0/20
  "subnet-01aef7bfff0e73003"   # us-east-1c - 10.30.80.0/20
]

# SSH Key
key_name = "tunefy-prod-key"

# Your Public IP for SSH access to bastion
allowed_ssh_cidr = "165.1.173.37/32"

# Kubernetes Cluster
cluster_name = "tunefy-prod"

# Instance Types (c7i-flex.large as per requirements)
cp_instance_type      = "c7i-flex.large"  # Control planes: 2 vCPU, 4GB RAM
wk_instance_type      = "c7i-flex.large"  # Workers: 2 vCPU, 4GB RAM
bastion_instance_type = "t3.micro"        # Bastion can stay small

# IAM Instance Profile (from platform module)
# This should exist from your previous setup
nodes_instance_profile_name = "tunefy-prod-nodes"

# Additional Tags (Shared account - identify your project)
tags = {
  Owner      = "david.cifuentes"
  Team       = "DevOps"
  CostCenter = "Engineering"
  Terraform  = "true"
}

# Octopus Deploy Configuration (Cross-Account CI/CD)
octopus_server_url = "http://10.20.63.199:8080"
octopus_api_key    = "API-I7EFXMWA7XMX8RSOKLDIGOVNVHGBA0L"
octopus_space      = "Default"
