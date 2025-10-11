locals {
  name        = "${var.project}-${var.env}"
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.env
    },
    var.tags
  )
}

# Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Current AWS account ID
data "aws_caller_identity" "current" {}

# Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}
