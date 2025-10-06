terraform {
  required_version = ">= 1.6"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
  
  backend "s3" {
    bucket         = "tunefy-tf-state"
    key            = "compute-prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tunefy-tf-locks"
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
      Component   = "compute-prod"
    }
  }
}
