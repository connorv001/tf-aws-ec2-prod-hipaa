# DNS Module for Enterprise Odoo Deployment
# Route 53 configuration for domain management

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.domain_name}-hosted-zone"
    Type = "DNS"
  })
}

# A record for the main domain
resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# AAAA record for IPv6 (if ALB supports it)
resource "aws_route53_record" "main_ipv6" {
  count = var.enable_ipv6 ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# WWW subdomain
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Health check for the main domain
resource "aws_route53_health_check" "main" {
  fqdn                            = var.domain_name
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = var.health_check_path
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = data.aws_region.current.name
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.health_check.alarm_name
  insufficient_data_health_status = "Failure"

  tags = merge(var.tags, {
    Name = "${var.domain_name}-health-check"
    Type = "DNS"
  })
}

# CloudWatch alarm for health check
resource "aws_cloudwatch_metric_alarm" "health_check" {
  alarm_name          = "${replace(var.domain_name, ".", "-")}-health-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors the health of ${var.domain_name}"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.domain_name}-health-check-alarm"
    Type = "Monitoring"
  })
}

# MX record for email (if needed)
resource "aws_route53_record" "mx" {
  count = length(var.mx_records) > 0 ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300
  records = var.mx_records
}

# TXT record for domain verification and SPF
resource "aws_route53_record" "txt" {
  count = length(var.txt_records) > 0 ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = var.txt_records
}

# CNAME record for additional subdomains
resource "aws_route53_record" "cname" {
  for_each = var.cname_records

  zone_id = aws_route53_zone.main.zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = 300
  records = [each.value]
}

# CAA record for certificate authority authorization
resource "aws_route53_record" "caa" {
  count = var.enable_caa_record ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issue \"amazontrust.com\"",
    "0 issue \"awstrust.com\"",
    "0 issue \"amazonaws.com\"",
    "0 iodef \"mailto:security@${var.domain_name}\""
  ]
}

# Subdomain for API (if needed)
resource "aws_route53_record" "api" {
  count = var.create_api_subdomain ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Subdomain for admin (if needed)
resource "aws_route53_record" "admin" {
  count = var.create_admin_subdomain ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "admin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Route 53 Resolver Query Logging (for compliance)
resource "aws_route53_resolver_query_log_config" "main" {
  count = var.enable_query_logging ? 1 : 0

  name            = "${replace(var.domain_name, ".", "-")}-query-logs"
  destination_arn = aws_cloudwatch_log_group.query_logs[0].arn

  tags = merge(var.tags, {
    Name = "${var.domain_name}-query-logs"
    Type = "DNS"
  })
}

# CloudWatch Log Group for DNS query logs
resource "aws_cloudwatch_log_group" "query_logs" {
  count = var.enable_query_logging ? 1 : 0

  name              = "/aws/route53/${replace(var.domain_name, ".", "-")}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.domain_name}-query-logs"
    Type = "Monitoring"
  })
}

# Route 53 Resolver Query Log Config Association
resource "aws_route53_resolver_query_log_config_association" "main" {
  count = var.enable_query_logging ? 1 : 0

  resolver_query_log_config_id = aws_route53_resolver_query_log_config.main[0].id
  resource_id                  = var.vpc_id
}

# Data source for current region
data "aws_region" "current" {}

# CloudWatch Dashboard for DNS metrics
resource "aws_cloudwatch_dashboard" "dns" {
  dashboard_name = "${replace(var.domain_name, ".", "-")}-dns-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", aws_route53_health_check.main.id],
            ["AWS/Route53", "HealthCheckPercentHealthy", "HealthCheckId", aws_route53_health_check.main.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Route 53 Health Check Status"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Route53", "QueryCount", "HostedZoneId", aws_route53_zone.main.zone_id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "DNS Query Count"
          period  = 300
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.domain_name}-dns-dashboard"
    Type = "Monitoring"
  })
}