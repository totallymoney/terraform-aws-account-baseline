# Findings that nobody is told about are findings nobody acts on. GuardDuty and
# Security Hub both write to EventBridge, so route the serious ones to the same
# topic the alarms use.
#
# The input transformers matter: without them the email is a page of raw JSON
# and people stop reading it.

locals {
  notify_guardduty   = var.enable_alarms && var.enable_guardduty
  notify_securityhub = var.enable_alarms && var.enable_securityhub
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = local.notify_guardduty ? 1 : 0

  name        = "${var.name}-guardduty-findings"
  description = "GuardDuty findings at or above the configured severity"
  tags        = local.tags

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.guardduty_notify_min_severity] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_findings" {
  count = local.notify_guardduty ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "sns"
  arn       = aws_sns_topic.alarms[0].arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      account     = "$.detail.accountId"
      region      = "$.detail.region"
      description = "$.detail.description"
    }
    input_template = "\"GuardDuty severity <severity>: <type> in account <account> (<region>). <description>\""
  }
}

resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  count = local.notify_securityhub ? 1 : 0

  name        = "${var.name}-securityhub-findings"
  description = "New active Security Hub findings at the configured severities"
  tags        = local.tags

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity    = { Label = var.securityhub_notify_severities }
        Workflow    = { Status = ["NEW"] }
        RecordState = ["ACTIVE"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub_findings" {
  count = local.notify_securityhub ? 1 : 0

  rule      = aws_cloudwatch_event_rule.securityhub_findings[0].name
  target_id = "sns"
  arn       = aws_sns_topic.alarms[0].arn

  input_transformer {
    input_paths = {
      severity = "$.detail.findings[0].Severity.Label"
      title    = "$.detail.findings[0].Title"
      account  = "$.detail.findings[0].AwsAccountId"
      resource = "$.detail.findings[0].Resources[0].Id"
    }
    input_template = "\"Security Hub <severity>: <title> in account <account>. Resource: <resource>\""
  }
}
