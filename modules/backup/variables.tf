# Variables for Backup Module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "rds_instance_arn" {
  description = "ARN of the RDS instance to backup"
  type        = string
}

variable "backup_service_role_arn" {
  description = "ARN of the backup service role"
  type        = string
}

variable "backup_schedule" {
  description = "Cron expression for backup schedule"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "backup_cold_storage_days" {
  description = "Number of days before moving backups to cold storage"
  type        = number
  default     = 90
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = true
}

variable "backup_region" {
  description = "Region for backup replication"
  type        = string
  default     = "us-east-1"
}

variable "enable_backup_validation" {
  description = "Enable automated backup validation"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "List of ARNs to notify when backup alarms trigger"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}