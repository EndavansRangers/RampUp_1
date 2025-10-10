# ============================================
# S3 Bucket for PostgreSQL Backups
# ============================================

resource "aws_s3_bucket" "postgresql_backups" {
  bucket = "${local.name}-postgresql-backups"
  
  tags = merge(local.common_tags, {
    Name    = "${local.name}-postgresql-backups"
    Purpose = "CloudNativePG Backups"
  })
}

# Enable versioning for backup safety
resource "aws_s3_bucket_versioning" "postgresql_backups" {
  bucket = aws_s3_bucket.postgresql_backups.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "postgresql_backups" {
  bucket = aws_s3_bucket.postgresql_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "postgresql_backups" {
  bucket = aws_s3_bucket.postgresql_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy (30 days retention)
resource "aws_s3_bucket_lifecycle_configuration" "postgresql_backups" {
  bucket = aws_s3_bucket.postgresql_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# IAM Policy for nodes to access S3 (for CloudNativePG)
data "aws_iam_policy_document" "s3_postgresql_backups" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.postgresql_backups.arn,
      "${aws_s3_bucket.postgresql_backups.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_postgresql_backups" {
  name        = "${local.name}-s3-postgresql-backups"
  description = "Allow CloudNativePG to access S3 for backups"
  policy      = data.aws_iam_policy_document.s3_postgresql_backups.json
  tags        = merge(local.common_tags, { Name = "${local.name}-s3-postgresql-backups" })
}

resource "aws_iam_role_policy_attachment" "nodes_s3_backups" {
  role       = aws_iam_role.nodes.name
  policy_arn = aws_iam_policy.s3_postgresql_backups.arn
}



