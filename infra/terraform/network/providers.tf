terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
  backend "s3" {
    bucket       = "tunefy-tf-state"          # <- tu bucket
    key          = "network/terraform.tfstate"
    region       = "us-east-1"                # <- región REAL del bucket
    use_lockfile = true                       # <--- nuevo
  }
}
