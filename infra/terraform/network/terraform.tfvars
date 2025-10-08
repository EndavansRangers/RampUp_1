# Tunefy Network Infrastructure - Shared Account (david.cifuentes)
# Account: 315251037468

project   = "tunefy"
region    = "us-east-1"
env       = "dev"  # Starting with DEV environment (migrate existing setup)
azs       = ["us-east-1a", "us-east-1b", "us-east-1c"]
vpc_cidr  = "10.20.0.0/16"

# Dev: Cost optimization (1 NAT gateway)
nat_per_az = false

# Tags for shared account identification
tags = {
  owner      = "david.cifuentes"
  project    = "tunefy-david.cifuentes"
  env        = "dev"
}
