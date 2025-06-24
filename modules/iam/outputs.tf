# Outputs for IAM Module

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_instance_profile.arn
}

output "ec2_instance_role_arn" {
  description = "ARN of the EC2 instance role"
  value       = aws_iam_role.ec2_instance_role.arn
}

output "backup_service_role_arn" {
  description = "ARN of the backup service role"
  value       = aws_iam_role.backup_service_role.arn
}

output "rds_enhanced_monitoring_role_arn" {
  description = "ARN of the RDS enhanced monitoring role"
  value       = aws_iam_role.rds_enhanced_monitoring.arn
}

output "cloudwatch_events_role_arn" {
  description = "ARN of the CloudWatch Events role"
  value       = aws_iam_role.cloudwatch_events_role.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "cross_account_backup_role_arn" {
  description = "ARN of the cross-account backup role"
  value       = var.enable_cross_account_backup ? aws_iam_role.cross_account_backup[0].arn : null
}