project   = "tunefy"
region    = "us-east-1"
env       = "prod"
azs       = ["us-east-1a","us-east-1b","us-east-1c"]
vpc_cidr  = "10.30.0.0/16"

# Prod: HA with multiple NATs
nat_per_az = false

tags = {
  Owner = "platform"
}

# VPC Peering from Dev
vpc_peering_connection_id = "pcx-0b791f4f29afed679"
dev_vpc_cidr              = "10.20.0.0/16"
