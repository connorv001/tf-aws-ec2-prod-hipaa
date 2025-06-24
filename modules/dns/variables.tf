# Variables for DNS Module

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  type        = string
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
  default     = "/web/health"
}

variable "enable_ipv6" {
  description = "Enable IPv6 AAAA records"
  type        = bool
  default     = false
}

variable "mx_records" {
  description = "List of MX records for email"
  type        = list(string)
  default     = []
}

variable "txt_records" {
  description = "List of TXT records for domain verification"
  type        = list(string)
  default     = []
}

variable "cname_records" {
  description = "Map of CNAME records (subdomain -> target)"
  type        = map(string)
  default     = {}
}

variable "enable_caa_record" {
  description = "Enable CAA record for certificate authority authorization"
  type        = bool
  default     = true
}

variable "create_api_subdomain" {
  description = "Create API subdomain"
  type        = bool
  default     = false
}

variable "create_admin_subdomain" {
  description = "Create admin subdomain"
  type        = bool
  default     = false
}

variable "enable_query_logging" {
  description = "Enable Route 53 query logging"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID for query logging association"
  type        = string
  default     = ""
}

variable "alarm_actions" {
  description = "List of ARNs to notify when health check alarm triggers"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}