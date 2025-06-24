# Variables for S3 Module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for backup bucket"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "Region for cross-region replication"
  type        = string
  default     = "us-east-1"
}

variable "backup_lifecycle_days" {
  description = "Number of days before transitioning backup files to IA storage"
  type        = number
  default     = 30
}

variable "media_lifecycle_days" {
  description = "Number of days before transitioning media files to IA storage"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}