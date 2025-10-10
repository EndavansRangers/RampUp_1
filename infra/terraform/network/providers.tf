terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
  backend "s3" {
    bucket       = "tunefy-tf-state-038686090046"
    key          = "network/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
