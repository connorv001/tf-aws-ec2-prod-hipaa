# SSL Module for Enterprise Odoo Deployment
# AWS Certificate Manager for SSL/TLS certificates

# Request SSL certificate from AWS Certificate Manager
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.domain_name}-ssl-certificate"
    Type = "Security"
  })
}

# DNS validation records
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# CloudWatch Log Group for certificate monitoring
resource "aws_cloudwatch_log_group" "certificate_logs" {
  name              = "/aws/acm/${replace(var.domain_name, ".", "-")}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.domain_name}-certificate-logs"
    Type = "Security"
  })
}

# CloudWatch Alarm for certificate expiration
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  alarm_name          = "${replace(var.domain_name, ".", "-")}-certificate-expiry"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = "86400"  # 24 hours
  statistic           = "Average"
  threshold           = "30"     # Alert 30 days before expiry
  alarm_description   = "SSL certificate will expire in less than 30 days"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    CertificateArn = aws_acm_certificate.main.arn
  }

  tags = merge(var.tags, {
    Name = "${var.domain_name}-certificate-expiry-alarm"
    Type = "Security"
  })
}

# EventBridge rule for certificate events
resource "aws_cloudwatch_event_rule" "certificate_events" {
  name        = "${replace(var.domain_name, ".", "-")}-certificate-events"
  description = "Capture certificate manager events"

  event_pattern = jsonencode({
    source      = ["aws.acm"]
    detail-type = ["ACM Certificate Approaching Expiration"]
    detail = {
      certificateArn = [aws_acm_certificate.main.arn]
    }
  })

  tags = merge(var.tags, {
    Name = "${var.domain_name}-certificate-events"
    Type = "Security"
  })
}

# EventBridge target for certificate notifications
resource "aws_cloudwatch_event_target" "certificate_notification" {
  count     = length(var.notification_topics) > 0 ? 1 : 0
  rule      = aws_cloudwatch_event_rule.certificate_events.name
  target_id = "CertificateNotificationTarget"
  arn       = var.notification_topics[0]
}

# Lambda function for certificate monitoring (optional)
resource "aws_lambda_function" "certificate_monitor" {
  count = var.enable_certificate_monitoring ? 1 : 0

  filename         = data.archive_file.certificate_monitor_zip[0].output_path
  function_name    = "${replace(var.domain_name, ".", "-")}-certificate-monitor"
  role            = aws_iam_role.certificate_monitor_lambda[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.certificate_monitor_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      CERTIFICATE_ARN = aws_acm_certificate.main.arn
      DOMAIN_NAME     = var.domain_name
    }
  }

  tags = merge(var.tags, {
    Name = "${var.domain_name}-certificate-monitor"
    Type = "Security"
  })
}

# Lambda function code for certificate monitoring
data "archive_file" "certificate_monitor_zip" {
  count = var.enable_certificate_monitoring ? 1 : 0

  type        = "zip"
  output_path = "/tmp/certificate_monitor.zip"
  source {
    content = templatefile("${path.module}/lambda/certificate_monitor.py", {
      certificate_arn = aws_acm_certificate.main.arn
      domain_name     = var.domain_name
    })
    filename = "index.py"
  }
}

# IAM role for certificate monitoring Lambda
resource "aws_iam_role" "certificate_monitor_lambda" {
  count = var.enable_certificate_monitoring ? 1 : 0
  name  = "${replace(var.domain_name, ".", "-")}-certificate-monitor-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.domain_name}-certificate-monitor-lambda-role"
    Type = "Security"
  })
}

# IAM policy for certificate monitoring Lambda
resource "aws_iam_role_policy" "certificate_monitor_lambda" {
  count = var.enable_certificate_monitoring ? 1 : 0
  name  = "${replace(var.domain_name, ".", "-")}-certificate-monitor-lambda-policy"
  role  = aws_iam_role.certificate_monitor_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListCertificates"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.notification_topics
      }
    ]
  })
}

# CloudWatch Event Rule for scheduled certificate checks
resource "aws_cloudwatch_event_rule" "certificate_check_schedule" {
  count = var.enable_certificate_monitoring ? 1 : 0

  name                = "${replace(var.domain_name, ".", "-")}-certificate-check"
  description         = "Scheduled certificate expiry check"
  schedule_expression = "rate(1 day)"

  tags = merge(var.tags, {
    Name = "${var.domain_name}-certificate-check-schedule"
    Type = "Security"
  })
}

# CloudWatch Event Target for scheduled certificate checks
resource "aws_cloudwatch_event_target" "certificate_check_target" {
  count     = var.enable_certificate_monitoring ? 1 : 0
  rule      = aws_cloudwatch_event_rule.certificate_check_schedule[0].name
  target_id = "CertificateCheckTarget"
  arn       = aws_lambda_function.certificate_monitor[0].arn
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "certificate_check_permission" {
  count = var.enable_certificate_monitoring ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.certificate_monitor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.certificate_check_schedule[0].arn
}