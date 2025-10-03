terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "tunefy-terraform-state-365074502389"
    key            = "dns-records/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tunefy-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.env
      ManagedBy   = "Terraform"
    }
  }
}
