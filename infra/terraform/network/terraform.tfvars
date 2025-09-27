project   = "tunefy"
region    = "us-east-1"
env       = "dev"  # o "prod"
azs       = ["us-east-1a","us-east-1b","us-east-1c"]
vpc_cidr  = "10.20.0.0/16"

# Dev: ahorro (1 NAT). Prod: HA (3 NATs)
nat_per_az = false

tags = {
  Owner = "platform"
}
