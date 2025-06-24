# Monitoring Module for Enterprise Odoo Deployment
# Comprehensive CloudWatch monitoring and alerting

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alerts"
    Type = "Monitoring"
  })
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

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
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", split("/", var.alb_arn)[1]],
            [".", "RequestCount", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Application Load Balancer Metrics"
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
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", var.autoscaling_group_name],
            [".", "GroupInServiceInstances", ".", "."],
            [".", "GroupTotalInstances", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Auto Scaling Group Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."],
            [".", "ReadLatency", ".", "."],
            [".", "WriteLatency", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "RDS Database Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.backup_bucket_name, "StorageType", "StandardStorage"],
            [".", "NumberOfObjects", ".", ".", ".", "AllStorageTypes"],
            [".", "BucketSizeBytes", "BucketName", var.media_bucket_name, "StorageType", "StandardStorage"],
            [".", "NumberOfObjects", ".", ".", ".", "AllStorageTypes"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "S3 Storage Metrics"
          period  = 86400
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-dashboard"
    Type = "Monitoring"
  })
}

# ALB Target Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = split("/", var.alb_arn)[1]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-response-time-alarm"
    Type = "Monitoring"
  })
}

# ALB 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = split("/", var.alb_arn)[1]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-5xx-errors-alarm"
    Type = "Monitoring"
  })
}

# Auto Scaling Group Instance Health Alarm
resource "aws_cloudwatch_metric_alarm" "asg_instance_health" {
  alarm_name          = "${var.project_name}-${var.environment}-asg-instance-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ASG healthy instances"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-asg-health-alarm"
    Type = "Monitoring"
  })
}

# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-cpu-alarm"
    Type = "Monitoring"
  })
}

# RDS Connection Count Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "150"
  alarm_description   = "This metric monitors RDS connection count"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-connections-alarm"
    Type = "Monitoring"
  })
}

# RDS Free Memory Alarm
resource "aws_cloudwatch_metric_alarm" "rds_free_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-free-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "268435456"  # 256 MB in bytes
  alarm_description   = "This metric monitors RDS free memory"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-memory-alarm"
    Type = "Monitoring"
  })
}

# Custom Metric for Odoo Application Health
resource "aws_cloudwatch_log_metric_filter" "odoo_errors" {
  name           = "${var.project_name}-${var.environment}-odoo-errors"
  log_group_name = "/aws/ec2/${var.project_name}-${var.environment}/odoo"
  pattern        = "ERROR"

  metric_transformation {
    name      = "OdooErrors"
    namespace = "Custom/Odoo"
    value     = "1"
  }
}

# Alarm for Odoo Application Errors
resource "aws_cloudwatch_metric_alarm" "odoo_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-odoo-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "OdooErrors"
  namespace           = "Custom/Odoo"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Odoo application errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-odoo-errors-alarm"
    Type = "Monitoring"
  })
}

# CloudWatch Insights Queries for troubleshooting
resource "aws_cloudwatch_query_definition" "odoo_performance" {
  name = "${var.project_name}-${var.environment}-odoo-performance"

  log_group_names = [
    "/aws/ec2/${var.project_name}-${var.environment}/odoo"
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /slow query/
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "nginx_errors" {
  name = "${var.project_name}-${var.environment}-nginx-errors"

  log_group_names = [
    "/aws/ec2/${var.project_name}-${var.environment}/nginx"
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /error/
| sort @timestamp desc
| limit 100
EOF
}

# EventBridge Rule for EC2 Instance State Changes
resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name        = "${var.project_name}-${var.environment}-ec2-state-change"
  description = "Capture EC2 instance state changes"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["terminated", "stopped", "stopping"]
    }
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ec2-state-change"
    Type = "Monitoring"
  })
}

# EventBridge Target for EC2 State Changes
resource "aws_cloudwatch_event_target" "ec2_state_change_sns" {
  rule      = aws_cloudwatch_event_rule.ec2_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}

# EventBridge Rule for RDS Events
resource "aws_cloudwatch_event_rule" "rds_events" {
  name        = "${var.project_name}-${var.environment}-rds-events"
  description = "Capture RDS events"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Instance Event", "RDS DB Cluster Event"]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-events"
    Type = "Monitoring"
  })
}

# EventBridge Target for RDS Events
resource "aws_cloudwatch_event_target" "rds_events_sns" {
  rule      = aws_cloudwatch_event_rule.rds_events.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_detector" "cost" {
  name         = "${var.project_name}-${var.environment}-cost-anomaly"
  monitor_type = "DIMENSIONAL"

  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["Amazon Elastic Compute Cloud - Compute", "Amazon Relational Database Service"]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-cost-anomaly"
    Type = "Monitoring"
  })
}

# Cost Anomaly Subscription
resource "aws_ce_anomaly_subscription" "cost" {
  count = var.notification_email != "" ? 1 : 0

  name      = "${var.project_name}-${var.environment}-cost-alerts"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.cost.arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.notification_email
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-cost-alerts"
    Type = "Monitoring"
  })
}

# Data source for current region
data "aws_region" "current" {}