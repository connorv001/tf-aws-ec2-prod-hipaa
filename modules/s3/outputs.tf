# Outputs for S3 Module

output "backup_bucket_name" {
  description = "Name of the backup S3 bucket"
  value       = aws_s3_bucket.backup.bucket
}

output "backup_bucket_arn" {
  description = "ARN of the backup S3 bucket"
  value       = aws_s3_bucket.backup.arn
}

output "backup_bucket_id" {
  description = "ID of the backup S3 bucket"
  value       = aws_s3_bucket.backup.id
}

output "media_bucket_name" {
  description = "Name of the media S3 bucket"
  value       = aws_s3_bucket.media.bucket
}

output "media_bucket_arn" {
  description = "ARN of the media S3 bucket"
  value       = aws_s3_bucket.media.arn
}

output "media_bucket_id" {
  description = "ID of the media S3 bucket"
  value       = aws_s3_bucket.media.id
}

output "kms_key_id" {
  description = "ID of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3_key.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3_key.arn
}

output "backup_replica_bucket_name" {
  description = "Name of the backup replica S3 bucket"
  value       = var.enable_cross_region_replication ? aws_s3_bucket.backup_replica[0].bucket : null
}

output "backup_replica_bucket_arn" {
  description = "ARN of the backup replica S3 bucket"
  value       = var.enable_cross_region_replication ? aws_s3_bucket.backup_replica[0].arn : null
}