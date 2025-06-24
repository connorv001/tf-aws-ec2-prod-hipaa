# Variables for IAM Module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "backup_bucket_arn" {
  description = "ARN of the backup S3 bucket"
  type        = string
}

variable "media_bucket_arn" {
  description = "ARN of the media S3 bucket"
  type        = string
}

variable "enable_cross_account_backup" {
  description = "Enable cross-account backup access"
  type        = bool
  default     = false
}

variable "backup_account_arn" {
  description = "ARN of the backup account for cross-account access"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "External ID for cross-account access"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}