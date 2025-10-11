# Tunefy Dev - FREE TIER Account
# Account: 638325785916

project   = "tunefy"
region    = "us-east-1"
env       = "dev"
key_name  = "tunefy-dev-key"

# VPC from network module (via data source)
# No need to hardcode IDs

# IAM Instance Profile for K8s nodes
nodes_instance_profile_name = "tunefy-dev-nodes"

# Your current public IP for SSH access
allowed_ssh_cidr = "165.1.173.37/32"

# Instance types (FREE TIER ELIGIBLE)
# c7i-flex.large: 750h first year for intensive workloads (CP, CI/CD)
# t3.micro: 750h/month permanent for workers and bastion
cp_instance_type = "c7i-flex.large"  # Control Plane - FREE TIER (750h first year)
wk_instance_type = "t3.micro"        # Workers - FREE TIER (750h/month permanent)
tc_instance_type = "c7i-flex.large"  # TeamCity - FREE TIER (750h first year)
oc_instance_type = "c7i-flex.large"  # Octopus - FREE TIER (750h first year)

# Tags for Free Tier account identification
tags = {
  owner   = "david.cifuentes"
  account = "free-tier"
}
