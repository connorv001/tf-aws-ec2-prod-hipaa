# Outputs for Monitoring Module

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "cost_anomaly_detector_arn" {
  description = "ARN of the cost anomaly detector"
  value       = aws_ce_anomaly_detector.cost.arn
}

output "alb_response_time_alarm_arn" {
  description = "ARN of the ALB response time alarm"
  value       = aws_cloudwatch_metric_alarm.alb_response_time.arn
}

output "alb_5xx_errors_alarm_arn" {
  description = "ARN of the ALB 5XX errors alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx_errors.arn
}

output "rds_cpu_alarm_arn" {
  description = "ARN of the RDS CPU alarm"
  value       = aws_cloudwatch_metric_alarm.rds_cpu.arn
}

output "rds_connections_alarm_arn" {
  description = "ARN of the RDS connections alarm"
  value       = aws_cloudwatch_metric_alarm.rds_connections.arn
}

output "odoo_errors_alarm_arn" {
  description = "ARN of the Odoo errors alarm"
  value       = aws_cloudwatch_metric_alarm.odoo_errors.arn
}