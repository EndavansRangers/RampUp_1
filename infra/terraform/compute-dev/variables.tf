variable "project" { type = string }
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "env" {
  type    = string
  default = "dev"
}
variable "key_name" {
  description = "Key pair name for SSH"
  type        = string
}

# IDs from vpc and subnets


# IAM de nodos
variable "nodes_instance_profile_name" { type = string }

# Instance types
variable "cp_instance_type" {
  type    = string
  default = "c7i-flex.large"
}
variable "wk_instance_type" {
  type    = string
  default = "t3.small"
}
variable "tc_instance_type" {
  type    = string
  default = "c7i-flex.large"
}
variable "oc_instance_type" {
  type    = string
  default = "c7i-flex.large"
}

# IP for bastion SG (CIDR /32)
variable "allowed_ssh_cidr" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type    = string
  default = "tunefy-dev"
}
