# ============================================================
# Module: notifications — Pipeline Alerts & Approvals
# ============================================================
# WAF Pillars: Operational Excellence, Reliability
#
# Creates:
#   - SNS topic for pipeline alerts (failure, success)
#   - SNS topic for manual approval requests
#   - EventBridge rule: pipeline state changes → SNS
#   - CloudWatch alarm → SNS for repeated failures
#   - Optional Lambda for Slack webhook delivery
# ============================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.organization_name}-${var.environment}"
}

# ---- Pipeline Alerts Topic ----------------------------------
resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-pipeline-alerts"
  kms_master_key_id = var.kms_key_arn
  tags              = { Name = "${local.name_prefix}-pipeline-alerts" }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.pipeline_notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.pipeline_notification_email
}

# ---- Approval Topic -----------------------------------------
resource "aws_sns_topic" "approval" {
  name              = "${local.name_prefix}-pipeline-approval"
  kms_master_key_id = var.kms_key_arn
  tags              = { Name = "${local.name_prefix}-pipeline-approval" }
}

resource "aws_sns_topic_subscription" "approval_email" {
  count     = var.approval_notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.approval.arn
  protocol  = "email"
  endpoint  = var.approval_notification_email
}

# ---- SNS Topic Policy ---------------------------------------
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodePipelinePublish"
        Effect = "Allow"
        Principal = {
          Service = ["codepipeline.amazonaws.com", "events.amazonaws.com"]
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.account_id }
        }
      }
    ]
  })
}

# ---- EventBridge: Pipeline State → SNS ----------------------
resource "aws_cloudwatch_event_rule" "pipeline_failed" {
  name        = "${local.name_prefix}-pipeline-failed"
  description = "Fires when any CodePipeline execution fails."

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail      = { state = ["FAILED"] }
  })
}

resource "aws_cloudwatch_event_target" "pipeline_failed_sns" {
  rule      = aws_cloudwatch_event_rule.pipeline_failed.name
  target_id = "PipelineFailedSNS"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      state     = "$.detail.state"
      execution = "$.detail.execution-id"
      time      = "$.time"
    }
    input_template = "\"Pipeline <pipeline> FAILED at <time>. Execution ID: <execution>. Check: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\""
  }
}

resource "aws_cloudwatch_event_rule" "pipeline_succeeded" {
  name        = "${local.name_prefix}-pipeline-succeeded"
  description = "Fires on successful CodePipeline execution."
  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail      = { state = ["SUCCEEDED"] }
  })
}

resource "aws_cloudwatch_event_target" "pipeline_succeeded_sns" {
  rule      = aws_cloudwatch_event_rule.pipeline_succeeded.name
  target_id = "PipelineSucceededSNS"
  arn       = aws_sns_topic.alerts.arn
}

# ---- EventBridge: Security Gate Failure → SNS ---------------
resource "aws_cloudwatch_event_rule" "security_gate_failed" {
  name        = "${local.name_prefix}-security-gate-failed"
  description = "Fires when a security gate CodeBuild stage fails."

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Action Execution State Change"]
    detail = {
      state      = ["FAILED"]
      actionName = ["SecretScan", "SAST", "ContainerScan", "IaCScan", "DAST"]
    }
  })
}

resource "aws_cloudwatch_event_target" "security_gate_failed_sns" {
  rule      = aws_cloudwatch_event_rule.security_gate_failed.name
  target_id = "SecurityGateSNS"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      pipeline = "$.detail.pipeline"
      action   = "$.detail.actionName"
      time     = "$.time"
    }
    input_template = "\"🚨 SECURITY GATE FAILED: <action> in pipeline <pipeline> at <time>. Review findings before merge.\""
  }
}

# ---- Optional: Slack Lambda notifier ------------------------
resource "aws_iam_role" "slack_notifier" {
  count = var.slack_webhook_secret_arn != "" ? 1 : 0
  name  = "${local.name_prefix}-slack-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "slack_notifier" {
  count = var.slack_webhook_secret_arn != "" ? 1 : 0
  name  = "slack-notifier-policy"
  role  = aws_iam_role.slack_notifier[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:${var.account_id}:log-group:/aws/lambda/*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.slack_webhook_secret_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.slack_notifier_dlq[0].arn]
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeVpcs"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "slack_notifier" {
  count             = var.slack_webhook_secret_arn != "" ? 1 : 0
  name              = "/aws/lambda/${local.name_prefix}-slack-notifier"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

# ---- SQS DLQ for Lambda failures ----------------------------
resource "aws_sqs_queue" "slack_notifier_dlq" {
  count             = var.slack_webhook_secret_arn != "" ? 1 : 0
  name              = "${local.name_prefix}-slack-notifier-dlq"
  kms_master_key_id = var.kms_key_arn
}

resource "aws_lambda_function" "slack_notifier" {
  count         = var.slack_webhook_secret_arn != "" ? 1 : 0
  function_name = "${local.name_prefix}-slack-notifier"
  role          = aws_iam_role.slack_notifier[0].arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = 10
  architectures = ["arm64"]
  kms_key_arn   = var.kms_key_arn

  filename         = data.archive_file.slack_notifier[0].output_path
  source_code_hash = data.archive_file.slack_notifier[0].output_base64sha256

  # VPC Configuration for CKV_AWS_117
  dynamic "vpc_config" {
    for_each = length(var.lambda_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.lambda_subnet_ids
      security_group_ids = var.lambda_security_group_ids
    }
  }

  # Concurrent execution limit for CKV_AWS_115
  reserved_concurrent_executions = 10

  # Code signing config for CKV_AWS_272
  code_signing_config_arn = var.lambda_code_signing_config_arn != "" ? var.lambda_code_signing_config_arn : null

  # DLQ for CKV_AWS_116
  dead_letter_config {
    target_arn = aws_sqs_queue.slack_notifier_dlq[0].arn
  }

  environment {
    variables = {
      SLACK_SECRET_ARN = var.slack_webhook_secret_arn
    }
  }

  tracing_config { mode = "Active" }

  depends_on = [aws_cloudwatch_log_group.slack_notifier]
}

data "archive_file" "slack_notifier" {
  count       = var.slack_webhook_secret_arn != "" ? 1 : 0
  type        = "zip"
  output_path = "/tmp/slack_notifier.zip"

  source {
    content  = <<-PYTHON
import json, os, urllib.request, boto3

def lambda_handler(event, context):
    secret_arn = os.environ["SLACK_SECRET_ARN"]
    sm = boto3.client("secretsmanager")
    webhook_url = sm.get_secret_value(SecretId=secret_arn)["SecretString"]
    message = event.get("Records", [{}])[0].get("Sns", {}).get("Message", str(event))
    payload = {"text": f":rotating_light: *DevSecOps Pipeline Alert*\n{message}"}
    req = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    urllib.request.urlopen(req)
    return {"statusCode": 200}
PYTHON
    filename = "handler.py"
  }
}

resource "aws_sns_topic_subscription" "slack" {
  count     = var.slack_webhook_secret_arn != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier[0].arn
}

resource "aws_lambda_permission" "sns_invoke_slack" {
  count         = var.slack_webhook_secret_arn != "" ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}
