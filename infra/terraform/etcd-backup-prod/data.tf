locals {
  bucket_name = "${var.project}-etcd-backups-${var.env}"
  common_tags = {
    Project     = var.project
    Environment = var.env
    Purpose     = "Disaster Recovery"
    Component   = "etcd-backup"
  }
}

data "aws_caller_identity" "current" {}
