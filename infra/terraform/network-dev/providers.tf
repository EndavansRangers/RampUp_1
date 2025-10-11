terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "dev"  # Uses ~/.aws/credentials profile 'dev'
  
  default_tags {
    tags = {
      Project     = "Tunefy"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
