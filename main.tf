# Enterprise Odoo Deployment on AWS
# HIPAA and SOC-2 Compliant Infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "odoo/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project             = var.project_name
      Environment         = var.environment
      Owner               = var.owner
      CostCenter          = var.cost_center
      Compliance          = "HIPAA-SOC2"
      ManagedBy          = "Terraform"
      BackupRequired     = "true"
      DataClassification = "confidential"
    }
  }
}

# Random password for RDS
resource "random_password" "rds_password" {
  length  = 32
  special = true
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for common configurations
locals {
  common_tags = {
    Project             = var.project_name
    Environment         = var.environment
    Owner               = var.owner
    CostCenter          = var.cost_center
    Compliance          = "HIPAA-SOC2"
    ManagedBy          = "Terraform"
    BackupRequired     = "true"
    DataClassification = "confidential"
  }

  # Availability zones (minimum 2 for Multi-AZ)
  azs = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = local.azs
  
  # Subnet CIDRs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  # VPC Flow Logs for compliance
  enable_flow_logs = true
  
  tags = local.common_tags
}

# Security Groups and NACLs
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
  
  # Allowed IP ranges for admin access
  admin_cidr_blocks = var.admin_cidr_blocks
  
  tags = local.common_tags
}

# IAM Roles and Policies
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  
  # S3 bucket ARNs (will be created by S3 module)
  backup_bucket_arn = module.s3.backup_bucket_arn
  media_bucket_arn  = module.s3.media_bucket_arn
  
  tags = local.common_tags
}

# S3 Buckets for backups and media
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  
  # Cross-region replication for disaster recovery
  enable_cross_region_replication = var.enable_cross_region_replication
  replication_region             = var.replication_region
  
  # Lifecycle policies for cost optimization
  backup_lifecycle_days = var.backup_lifecycle_days
  media_lifecycle_days  = var.media_lifecycle_days
  
  tags = local.common_tags
}

# SSL Certificates
module "ssl" {
  source = "./modules/ssl"

  domain_name = var.domain_name
  zone_id     = module.dns.zone_id
  
  # Subject Alternative Names
  subject_alternative_names = var.subject_alternative_names
  
  tags = local.common_tags
}

# RDS PostgreSQL Database
module "rds" {
  source = "./modules/rds"

  project_name = var.project_name
  environment  = var.environment
  
  # Network configuration
  vpc_id                = module.vpc.vpc_id
  database_subnet_ids   = module.vpc.database_subnet_ids
  database_security_group_id = module.security.database_security_group_id
  
  # Database configuration
  db_instance_class     = var.db_instance_class
  db_allocated_storage  = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = random_password.rds_password.result
  
  # High availability and backup
  multi_az                = true
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  # Performance and monitoring
  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn        = module.iam.rds_enhanced_monitoring_role_arn
  
  # Monitoring alarms
  alarm_actions = [module.monitoring.sns_topic_arn]
  
  tags = local.common_tags
}

# EC2 Instances and Load Balancer
module "ec2" {
  source = "./modules/ec2"

  project_name = var.project_name
  environment  = var.environment
  
  # Network configuration
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  # Security groups
  alb_security_group_id = module.security.alb_security_group_id
  ec2_security_group_id = module.security.ec2_security_group_id
  
  # Instance configuration
  instance_type        = var.instance_type
  key_pair_name       = var.key_pair_name
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  
  # SSL certificate
  certificate_arn = module.ssl.certificate_arn
  
  # IAM instance profile
  instance_profile_name = module.iam.ec2_instance_profile_name
  
  # Database connection
  db_endpoint = module.rds.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = random_password.rds_password.result
  
  # S3 buckets
  backup_bucket_name = module.s3.backup_bucket_name
  media_bucket_name  = module.s3.media_bucket_name
  
  # WAF Web ACL
  waf_web_acl_arn = module.security.waf_web_acl_arn
  
  tags = local.common_tags
}

# DNS Configuration
module "dns" {
  source = "./modules/dns"

  domain_name = var.domain_name
  
  # Load balancer DNS
  alb_dns_name    = module.ec2.alb_dns_name
  alb_zone_id     = module.ec2.alb_zone_id
  
  # Health check configuration
  health_check_path = var.health_check_path
  
  # VPC ID for query logging
  vpc_id = module.vpc.vpc_id
  
  tags = local.common_tags
}

# Monitoring and Alerting
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  
  # Resources to monitor
  alb_arn              = module.ec2.alb_arn
  target_group_arn     = module.ec2.target_group_arn
  autoscaling_group_name = module.ec2.autoscaling_group_name
  rds_instance_id      = module.rds.db_instance_id
  
  # S3 buckets
  backup_bucket_name = module.s3.backup_bucket_name
  media_bucket_name  = module.s3.media_bucket_name
  
  # Notification settings
  notification_email = var.notification_email
  
  tags = local.common_tags
}

# Backup Configuration
module "backup" {
  source = "./modules/backup"

  project_name = var.project_name
  environment  = var.environment
  
  # Resources to backup
  rds_instance_arn = module.rds.db_instance_arn
  
  # IAM role for backup service
  backup_service_role_arn = module.iam.backup_service_role_arn
  
  # Backup configuration
  backup_schedule           = var.backup_schedule
  backup_retention_days     = var.backup_retention_days
  backup_cold_storage_days  = var.backup_cold_storage_days
  
  # Cross-region backup
  enable_cross_region_backup = var.enable_cross_region_replication
  backup_region             = var.replication_region
  
  # Monitoring
  alarm_actions = [module.monitoring.sns_topic_arn]
  
  tags = local.common_tags
}