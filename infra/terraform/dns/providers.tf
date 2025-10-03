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
    key            = "dns/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tunefy-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}
