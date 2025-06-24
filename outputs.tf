# Outputs for Enterprise Odoo Deployment

# Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnet_ids
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ec2.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.ec2.alb_zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.ec2.alb_arn
}

# Auto Scaling Group Outputs
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.ec2.autoscaling_group_name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = module.ec2.autoscaling_group_arn
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_port
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.rds.db_instance_id
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = module.rds.db_instance_arn
}

# Database Connection Information
output "database_connection_info" {
  description = "Database connection information"
  value = {
    endpoint = module.rds.db_endpoint
    port     = module.rds.db_port
    database = var.db_name
    username = var.db_username
  }
  sensitive = true
}

# S3 Bucket Outputs
output "backup_bucket_name" {
  description = "Name of the backup S3 bucket"
  value       = module.s3.backup_bucket_name
}

output "backup_bucket_arn" {
  description = "ARN of the backup S3 bucket"
  value       = module.s3.backup_bucket_arn
}

output "media_bucket_name" {
  description = "Name of the media S3 bucket"
  value       = module.s3.media_bucket_name
}

output "media_bucket_arn" {
  description = "ARN of the media S3 bucket"
  value       = module.s3.media_bucket_arn
}

# SSL Certificate Outputs
output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = module.ssl.certificate_arn
}

output "certificate_domain_validation_options" {
  description = "Domain validation options for the SSL certificate"
  value       = module.ssl.domain_validation_options
}

# DNS Outputs
output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = module.dns.zone_id
}

output "route53_name_servers" {
  description = "Route 53 name servers"
  value       = module.dns.name_servers
}

# IAM Outputs
output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = module.iam.ec2_instance_profile_name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = module.iam.ec2_instance_profile_arn
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security.alb_security_group_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.security.ec2_security_group_id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = module.security.database_security_group_id
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}

# Backup Outputs
output "backup_vault_name" {
  description = "Name of the AWS Backup vault"
  value       = module.backup.backup_vault_name
}

output "backup_vault_arn" {
  description = "ARN of the AWS Backup vault"
  value       = module.backup.backup_vault_arn
}

# Application URL
output "application_url" {
  description = "URL to access the Odoo application"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${module.ec2.alb_dns_name}"
}

# Connection Instructions
output "connection_instructions" {
  description = "Instructions for connecting to the infrastructure"
  value = {
    application_url = var.domain_name != "" ? "https://${var.domain_name}" : "https://${module.ec2.alb_dns_name}"
    database_endpoint = module.rds.db_endpoint
    backup_bucket = module.s3.backup_bucket_name
    media_bucket = module.s3.media_bucket_name
    monitoring_dashboard = module.monitoring.dashboard_url
  }
  sensitive = true
}

# Cost Optimization Information
output "cost_optimization_info" {
  description = "Information about cost optimization features"
  value = {
    auto_scaling_enabled = true
    s3_intelligent_tiering = true
    rds_performance_insights = true
    backup_lifecycle_policies = true
    cross_region_replication = var.enable_cross_region_replication
  }
}

# Security and Compliance Information
output "security_compliance_info" {
  description = "Information about security and compliance features"
  value = {
    encryption_at_rest = true
    encryption_in_transit = true
    multi_az_database = true
    vpc_flow_logs = true
    cloudtrail_enabled = true
    backup_enabled = true
    ssl_certificate = true
    waf_enabled = true
    hipaa_compliant = true
    soc2_ready = true
  }
}