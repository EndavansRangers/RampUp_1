# S3 Bucket for etcd backups
resource "aws_s3_bucket" "etcd_backups" {
  bucket = local.bucket_name

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })
}

# Enable versioning for backup protection
resource "aws_s3_bucket_versioning" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"

    # Transition to Glacier after X days
    transition {
      days          = var.glacier_transition_days
      storage_class = "GLACIER"
    }

    # Delete after retention period
    expiration {
      days = var.retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# IAM Policy for backup access
resource "aws_iam_policy" "etcd_backup_s3" {
  name        = "${var.project}-${var.env}-etcd-backup-s3"
  description = "Allow etcd backup CronJob to write to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.etcd_backups.arn,
          "${aws_s3_bucket.etcd_backups.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

output "bucket_name" {
  value       = aws_s3_bucket.etcd_backups.id
  description = "S3 bucket name for etcd backups"
}

output "bucket_arn" {
  value       = aws_s3_bucket.etcd_backups.arn
  description = "S3 bucket ARN"
}

output "iam_policy_arn" {
  value       = aws_iam_policy.etcd_backup_s3.arn
  description = "IAM policy ARN for backup access - attach to nodes IAM role"
}
