# Backup Module for Enterprise Odoo Deployment
# AWS Backup service configuration for comprehensive data protection

# KMS Key for backup encryption
resource "aws_kms_key" "backup_key" {
  description             = "KMS key for AWS Backup encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow AWS Backup Service"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-kms-key"
    Type = "Security"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "backup_key_alias" {
  name          = "alias/${var.project_name}-${var.environment}-backup"
  target_key_id = aws_kms_key.backup_key.key_id
}

# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-${var.environment}-backup-vault"
  kms_key_arn = aws_kms_key.backup_key.arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-vault"
    Type = "Backup"
  })
}

# Backup Vault Lock Configuration (for compliance)
resource "aws_backup_vault_lock_configuration" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  changeable_for_days = 3
  max_retention_days  = 1200  # ~3.3 years
  min_retention_days  = 7
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-${var.environment}-backup-plan"

  # Daily backups with 30-day retention
  rule {
    rule_name         = "daily_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.backup_schedule

    lifecycle {
      cold_storage_after = var.backup_cold_storage_days
      delete_after       = var.backup_retention_days
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Daily"
      Automated  = "true"
    })

    copy_action {
      destination_vault_arn = aws_backup_vault.secondary[0].arn
      
      lifecycle {
        cold_storage_after = var.backup_cold_storage_days
        delete_after       = var.backup_retention_days
      }
    }
  }

  # Weekly backups with longer retention
  rule {
    rule_name         = "weekly_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * SUN *)"  # Weekly on Sunday at 3 AM

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365  # 1 year retention for weekly backups
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Weekly"
      Automated  = "true"
    })
  }

  # Monthly backups with extended retention
  rule {
    rule_name         = "monthly_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 4 1 * ? *)"  # Monthly on 1st at 4 AM

    lifecycle {
      cold_storage_after = 90
      delete_after       = 2555  # ~7 years retention for monthly backups
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Monthly"
      Automated  = "true"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-plan"
    Type = "Backup"
  })
}

# Secondary Backup Vault for cross-region replication
resource "aws_backup_vault" "secondary" {
  count = var.enable_cross_region_backup ? 1 : 0

  provider    = aws.backup_region
  name        = "${var.project_name}-${var.environment}-backup-vault-secondary"
  kms_key_arn = aws_kms_key.backup_key_secondary[0].arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-vault-secondary"
    Type = "Backup"
    Region = "Secondary"
  })
}

# KMS Key for secondary region
resource "aws_kms_key" "backup_key_secondary" {
  count = var.enable_cross_region_backup ? 1 : 0

  provider                = aws.backup_region
  description             = "KMS key for AWS Backup encryption in secondary region"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-kms-key-secondary"
    Type = "Security"
    Region = "Secondary"
  })
}

# Backup Selection for RDS
resource "aws_backup_selection" "rds" {
  iam_role_arn = var.backup_service_role_arn
  name         = "${var.project_name}-${var.environment}-rds-backup-selection"
  plan_id      = aws_backup_plan.main.id

  resources = [
    var.rds_instance_arn
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/BackupRequired"
      value = "true"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-backup-selection"
    Type = "Backup"
  })
}

# Backup Selection for EBS Volumes
resource "aws_backup_selection" "ebs" {
  iam_role_arn = var.backup_service_role_arn
  name         = "${var.project_name}-${var.environment}-ebs-backup-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupRequired"
    value = "true"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = var.project_name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ebs-backup-selection"
    Type = "Backup"
  })
}

# CloudWatch Alarms for backup monitoring
resource "aws_cloudwatch_metric_alarm" "backup_job_failed" {
  alarm_name          = "${var.project_name}-${var.environment}-backup-job-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors failed backup jobs"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-failed-alarm"
    Type = "Monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "backup_job_expired" {
  alarm_name          = "${var.project_name}-${var.environment}-backup-job-expired"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfBackupJobsExpired"
  namespace           = "AWS/Backup"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors expired backup jobs"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-expired-alarm"
    Type = "Monitoring"
  })
}

# EventBridge Rule for backup events
resource "aws_cloudwatch_event_rule" "backup_events" {
  name        = "${var.project_name}-${var.environment}-backup-events"
  description = "Capture AWS Backup events"

  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = [
      "Backup Job State Change",
      "Restore Job State Change",
      "Copy Job State Change"
    ]
    detail = {
      state = ["FAILED", "EXPIRED", "STOPPED"]
    }
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-events"
    Type = "Monitoring"
  })
}

# EventBridge Target for backup events
resource "aws_cloudwatch_event_target" "backup_events_sns" {
  count = length(var.alarm_actions) > 0 ? 1 : 0

  rule      = aws_cloudwatch_event_rule.backup_events.name
  target_id = "SendToSNS"
  arn       = var.alarm_actions[0]  # Assuming first action is SNS topic
}

# Lambda function for backup validation
resource "aws_lambda_function" "backup_validator" {
  count = var.enable_backup_validation ? 1 : 0

  filename         = data.archive_file.backup_validator_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-backup-validator"
  role            = aws_iam_role.backup_validator_lambda[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.backup_validator_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      BACKUP_VAULT_NAME = aws_backup_vault.main.name
      PROJECT_NAME      = var.project_name
      ENVIRONMENT       = var.environment
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-validator"
    Type = "Backup"
  })
}

# Lambda function code for backup validation
data "archive_file" "backup_validator_zip" {
  count = var.enable_backup_validation ? 1 : 0

  type        = "zip"
  output_path = "/tmp/backup_validator.zip"
  source {
    content = templatefile("${path.module}/lambda/backup_validator.py", {
      backup_vault_name = aws_backup_vault.main.name
      project_name      = var.project_name
      environment       = var.environment
    })
    filename = "index.py"
  }
}

# IAM role for backup validator Lambda
resource "aws_iam_role" "backup_validator_lambda" {
  count = var.enable_backup_validation ? 1 : 0
  name  = "${var.project_name}-${var.environment}-backup-validator-lambda-role"

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
    Name = "${var.project_name}-${var.environment}-backup-validator-lambda-role"
    Type = "IAM"
  })
}

# IAM policy for backup validator Lambda
resource "aws_iam_role_policy" "backup_validator_lambda" {
  count = var.enable_backup_validation ? 1 : 0
  name  = "${var.project_name}-${var.environment}-backup-validator-lambda-policy"
  role  = aws_iam_role.backup_validator_lambda[0].id

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
          "backup:ListRecoveryPoints",
          "backup:DescribeRecoveryPoint",
          "backup:ListBackupJobs",
          "backup:DescribeBackupJob"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.alarm_actions
      }
    ]
  })
}

# CloudWatch Event Rule for scheduled backup validation
resource "aws_cloudwatch_event_rule" "backup_validation_schedule" {
  count = var.enable_backup_validation ? 1 : 0

  name                = "${var.project_name}-${var.environment}-backup-validation"
  description         = "Scheduled backup validation"
  schedule_expression = "rate(1 day)"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-validation-schedule"
    Type = "Backup"
  })
}

# CloudWatch Event Target for backup validation
resource "aws_cloudwatch_event_target" "backup_validation_target" {
  count     = var.enable_backup_validation ? 1 : 0
  rule      = aws_cloudwatch_event_rule.backup_validation_schedule[0].name
  target_id = "BackupValidationTarget"
  arn       = aws_lambda_function.backup_validator[0].arn
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "backup_validation_permission" {
  count = var.enable_backup_validation ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_validator[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_validation_schedule[0].arn
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Provider for backup region
provider "aws" {
  alias  = "backup_region"
  region = var.backup_region
}