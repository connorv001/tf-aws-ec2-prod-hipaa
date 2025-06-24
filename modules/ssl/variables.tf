# Variables for SSL Module

variable "domain_name" {
  description = "Primary domain name for the SSL certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Subject Alternative Names for the SSL certificate"
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Route 53 hosted zone ID for DNS validation"
  type        = string
}

variable "alarm_actions" {
  description = "List of ARNs to notify when certificate expiry alarm triggers"
  type        = list(string)
  default     = []
}

variable "notification_topics" {
  description = "List of SNS topic ARNs for certificate notifications"
  type        = list(string)
  default     = []
}

variable "enable_certificate_monitoring" {
  description = "Enable advanced certificate monitoring with Lambda"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}