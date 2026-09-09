# A short list of alarms that are worth waking someone for. Everything else
# belongs in Security Hub, which reports without paging you.

locals {
  alarms_enabled = var.enable_cloudtrail && var.enable_alarms
  alarm_count    = local.alarms_enabled ? 1 : 0

  alarm_filters = {
    root-account-used = {
      description = "Root credentials were used"
      pattern     = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
      threshold   = 1
    }
    unauthorized-api-calls = {
      description = "Repeated denied API calls, often the first sign of a stolen credential"
      pattern     = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"
      threshold   = 20
    }
    iam-policy-changed = {
      description = "An IAM policy, role or user was changed"
      pattern     = "{ ($.eventName = Delete*Policy) || ($.eventName = Create*Policy) || ($.eventName = Attach*Policy) || ($.eventName = Detach*Policy) || ($.eventName = Put*Policy) }"
      threshold   = 1
    }
    console-signin-without-mfa = {
      description = "Console sign in that did not use MFA"
      pattern     = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.type != \"AssumedRole\") }"
      threshold   = 1
    }
    cloudtrail-changed = {
      description = "The trail itself was stopped, deleted or reconfigured"
      pattern     = "{ ($.eventName = StopLogging) || ($.eventName = DeleteTrail) || ($.eventName = UpdateTrail) }"
      threshold   = 1
    }
  }
}

resource "aws_sns_topic" "alarms" {
  count = local.alarm_count

  name              = "${var.name}-security-alarms"
  kms_master_key_id = "alias/aws/sns"
  tags              = local.tags
}

resource "aws_sns_topic_policy" "alarms" {
  count = local.alarm_count

  arn = aws_sns_topic.alarms[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.alarms[0].arn
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
      }
    }]
  })
}

# Confirmation arrives by email and has to be clicked.
resource "aws_sns_topic_subscription" "alarm_email" {
  count = local.alarms_enabled && var.alarm_email != null ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = local.alarms_enabled ? local.alarm_filters : {}

  name           = "${var.name}-${each.key}"
  pattern        = each.value.pattern
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name

  metric_transformation {
    name          = "${var.name}-${each.key}"
    namespace     = "SecurityBaseline"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms_enabled ? local.alarm_filters : {}

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = "SecurityBaseline"
  metric_name         = "${var.name}-${each.key}"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]
  tags                = local.tags
}
