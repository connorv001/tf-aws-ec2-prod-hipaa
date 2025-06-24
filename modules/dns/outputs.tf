# Outputs for DNS Module

output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_arn" {
  description = "Route 53 hosted zone ARN"
  value       = aws_route53_zone.main.arn
}

output "name_servers" {
  description = "Route 53 name servers"
  value       = aws_route53_zone.main.name_servers
}

output "health_check_id" {
  description = "Route 53 health check ID"
  value       = aws_route53_health_check.main.id
}

output "health_check_arn" {
  description = "Route 53 health check ARN"
  value       = aws_route53_health_check.main.arn
}

output "main_record_name" {
  description = "Main A record name"
  value       = aws_route53_record.main.name
}

output "www_record_name" {
  description = "WWW A record name"
  value       = aws_route53_record.www.name
}

output "api_record_name" {
  description = "API A record name"
  value       = var.create_api_subdomain ? aws_route53_record.api[0].name : null
}

output "admin_record_name" {
  description = "Admin A record name"
  value       = var.create_admin_subdomain ? aws_route53_record.admin[0].name : null
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL for DNS metrics"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.dns.dashboard_name}"
}