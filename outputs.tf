output "account_id" {
  description = "Account this baseline was applied to."
  value       = local.account_id
}

output "audit_log_kms_key_arn" {
  description = "CMK protecting CloudTrail, its log group and AWS Config."
  value       = try(aws_kms_key.logs[0].arn, null)
}

output "cloudtrail_bucket" {
  description = "Bucket holding the trail."
  value       = try(aws_s3_bucket.cloudtrail[0].id, null)
}

output "cloudtrail_arn" {
  description = "ARN of the trail."
  value       = try(aws_cloudtrail.this[0].arn, null)
}

output "security_alarm_topic_arn" {
  description = "SNS topic the security alarms publish to. Subscribe your on call rota here."
  value       = try(aws_sns_topic.alarms[0].arn, null)
}

output "guardduty_detector_id" {
  description = "GuardDuty detector, useful when enrolling this account into a delegated administrator."
  value       = try(aws_guardduty_detector.this[0].id, null)
}

output "github_oidc_role_arns" {
  description = "Role ARNs to put in the `role-to-assume` input of aws-actions/configure-aws-credentials."
  value       = { for k, r in aws_iam_role.github : k => r.arn }
}
