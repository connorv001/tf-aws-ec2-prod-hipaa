# Outputs for Backup Module

output "backup_vault_name" {
  description = "Name of the backup vault"
  value       = aws_backup_vault.main.name
}

output "backup_vault_arn" {
  description = "ARN of the backup vault"
  value       = aws_backup_vault.main.arn
}

output "backup_plan_id" {
  description = "ID of the backup plan"
  value       = aws_backup_plan.main.id
}

output "backup_plan_arn" {
  description = "ARN of the backup plan"
  value       = aws_backup_plan.main.arn
}

output "backup_kms_key_id" {
  description = "ID of the backup KMS key"
  value       = aws_kms_key.backup_key.key_id
}

output "backup_kms_key_arn" {
  description = "ARN of the backup KMS key"
  value       = aws_kms_key.backup_key.arn
}

output "secondary_backup_vault_name" {
  description = "Name of the secondary backup vault"
  value       = var.enable_cross_region_backup ? aws_backup_vault.secondary[0].name : null
}

output "secondary_backup_vault_arn" {
  description = "ARN of the secondary backup vault"
  value       = var.enable_cross_region_backup ? aws_backup_vault.secondary[0].arn : null
}

output "backup_validator_lambda_arn" {
  description = "ARN of the backup validator Lambda function"
  value       = var.enable_backup_validation ? aws_lambda_function.backup_validator[0].arn : null
}

output "backup_failed_alarm_arn" {
  description = "ARN of the backup failed alarm"
  value       = aws_cloudwatch_metric_alarm.backup_job_failed.arn
}

output "backup_expired_alarm_arn" {
  description = "ARN of the backup expired alarm"
  value       = aws_cloudwatch_metric_alarm.backup_job_expired.arn
}