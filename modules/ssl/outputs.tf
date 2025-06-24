# Outputs for SSL Module

output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "certificate_domain_name" {
  description = "Domain name of the SSL certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_subject_alternative_names" {
  description = "Subject Alternative Names of the SSL certificate"
  value       = aws_acm_certificate.main.subject_alternative_names
}

output "domain_validation_options" {
  description = "Domain validation options for the SSL certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}

output "certificate_status" {
  description = "Status of the SSL certificate"
  value       = aws_acm_certificate.main.status
}

output "certificate_expiry_alarm_arn" {
  description = "ARN of the certificate expiry CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.certificate_expiry.arn
}

output "certificate_monitor_lambda_arn" {
  description = "ARN of the certificate monitoring Lambda function"
  value       = var.enable_certificate_monitoring ? aws_lambda_function.certificate_monitor[0].arn : null
}