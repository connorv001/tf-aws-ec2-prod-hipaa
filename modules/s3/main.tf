# S3 Module for Enterprise Odoo Deployment
# HIPAA and SOC-2 Compliant S3 Buckets with Encryption

# Random suffix for bucket names to ensure uniqueness
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# KMS Key for S3 encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-s3-kms-key"
    Type = "Security"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${var.project_name}-${var.environment}-s3"
  target_key_id = aws_kms_key.s3_key.key_id
}

# Backup S3 Bucket
resource "aws_s3_bucket" "backup" {
  bucket = "${var.project_name}-${var.environment}-backup-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-backup"
    Type        = "Storage"
    Purpose     = "Backup"
    Compliance  = "HIPAA-SOC2"
  })
}

# Media S3 Bucket
resource "aws_s3_bucket" "media" {
  bucket = "${var.project_name}-${var.environment}-media-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-media"
    Type        = "Storage"
    Purpose     = "Media"
    Compliance  = "HIPAA-SOC2"
  })
}

# Backup Bucket Versioning
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Media Bucket Versioning
resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Backup Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Media Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Backup Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Media Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Backup Bucket Policy
resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.backup.arn,
          "${aws_s3_bucket.backup.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.backup.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# Media Bucket Policy
resource "aws_s3_bucket_policy" "media" {
  bucket = aws_s3_bucket.media.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.media.arn,
          "${aws_s3_bucket.media.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.media.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# Backup Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "backup_lifecycle"
    status = "Enabled"

    # Transition to IA after specified days
    transition {
      days          = var.backup_lifecycle_days
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Transition to Deep Archive after 365 days
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # Delete old versions after 2 years
    noncurrent_version_expiration {
      noncurrent_days = 730
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Media Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "media_lifecycle"
    status = "Enabled"

    # Transition to IA after specified days
    transition {
      days          = var.media_lifecycle_days
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 180 days
    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    # Delete old versions after 1 year
    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 Intelligent Tiering for cost optimization
resource "aws_s3_bucket_intelligent_tiering_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  name   = "backup_intelligent_tiering"

  status = "Enabled"

  # Optional deep archive configuration
  optional_fields {
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  name   = "media_intelligent_tiering"

  status = "Enabled"

  # Optional deep archive configuration
  optional_fields {
    bucket_key_enabled = true
  }
}

# Cross-Region Replication (if enabled)
resource "aws_s3_bucket_replication_configuration" "backup" {
  count = var.enable_cross_region_replication ? 1 : 0

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "backup_replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.backup_replica[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.s3_key_replica[0].arn
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.backup]
}

# Replica bucket for cross-region replication
resource "aws_s3_bucket" "backup_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replica
  bucket   = "${var.project_name}-${var.environment}-backup-replica-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-backup-replica"
    Type        = "Storage"
    Purpose     = "Backup-Replica"
    Compliance  = "HIPAA-SOC2"
  })
}

# KMS Key for replica region
resource "aws_kms_key" "s3_key_replica" {
  count                   = var.enable_cross_region_replication ? 1 : 0
  provider                = aws.replica
  description             = "KMS key for S3 bucket encryption in replica region"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-s3-kms-key-replica"
    Type = "Security"
  })
}

# Replica bucket versioning
resource "aws_s3_bucket_versioning" "backup_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.backup_replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Replica bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "backup_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.backup_replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key_replica[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# IAM Role for S3 Replication
resource "aws_iam_role" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-${var.environment}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-s3-replication-role"
    Type = "IAM"
  })
}

# IAM Policy for S3 Replication
resource "aws_iam_policy" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-${var.environment}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.backup.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.backup.arn
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.backup_replica[0].arn}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect = "Allow"
        Resource = [
          aws_kms_key.s3_key.arn
        ]
      },
      {
        Action = [
          "kms:GenerateDataKey"
        ]
        Effect = "Allow"
        Resource = [
          aws_kms_key.s3_key_replica[0].arn
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-s3-replication-policy"
    Type = "IAM"
  })
}

# Attach replication policy to role
resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.enable_cross_region_replication ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

# S3 Bucket Notification for backup monitoring
resource "aws_s3_bucket_notification" "backup_notification" {
  bucket = aws_s3_bucket.backup.id

  cloudwatch_configuration {
    cloudwatch_configuration_id = "backup-monitoring"
    events                      = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Provider for replica region
provider "aws" {
  alias  = "replica"
  region = var.replication_region
}