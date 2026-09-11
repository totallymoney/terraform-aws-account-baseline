variable "name" {
  type        = string
  description = "Prefix for every resource this module creates. Use something stable, such as the account alias."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "Must be 3-32 characters, lowercase letters, digits and hyphens, not starting or ending with a hyphen."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource that supports them."
  default     = {}
}

# --- CloudTrail ---

variable "enable_cloudtrail" {
  type        = bool
  description = "Create a multi-region organisation-agnostic trail. Turn off only if a trail is already delivered from a management account."
  default     = true
}

variable "cloudtrail_bucket_name" {
  type        = string
  description = "Override the generated CloudTrail bucket name."
  default     = null
}

variable "cloudtrail_retention_days" {
  type        = number
  description = "Days to keep CloudTrail objects in S3 before expiry."
  default     = 400

  validation {
    condition     = var.cloudtrail_retention_days >= 365
    error_message = "Keep at least 365 days. CIS AWS Foundations expects a year of history."
  }
}

variable "cloudtrail_log_group_retention_days" {
  type        = number
  description = "Days to keep the CloudTrail CloudWatch log group. Only used for the metric alarms."
  default     = 90
}

# --- Alarms ---

variable "enable_alarms" {
  type        = bool
  description = "Create CloudWatch metric filters and alarms over CloudTrail. Requires enable_cloudtrail."
  default     = true
}

variable "alarm_email" {
  type        = string
  description = "Address subscribed to the alarm topic. Leave null and subscribe by hand or point your own topic at it."
  default     = null
}

# --- Detection ---

variable "enable_guardduty" {
  type        = bool
  description = "Enable GuardDuty in this region."
  default     = true
}

variable "guardduty_features" {
  type        = list(string)
  description = "GuardDuty features to enable. Remove the ones you do not run to avoid paying for them."
  default     = ["S3_DATA_EVENTS", "EBS_MALWARE_PROTECTION", "RDS_LOGIN_EVENTS", "LAMBDA_NETWORK_LOGS"]
}

variable "enable_securityhub" {
  type        = bool
  description = "Enable Security Hub and subscribe to the standards below."
  default     = true
}

variable "securityhub_standards" {
  type        = list(string)
  description = "Standards to subscribe to, by short name. `cis-aws-foundations-benchmark` is v5.0.0; `cis-aws-foundations-benchmark-v3` is there for anyone mid migration."
  default     = ["aws-foundational-security-best-practices", "cis-aws-foundations-benchmark"]

  validation {
    condition = alltrue([
      for s in var.securityhub_standards : contains([
        "aws-foundational-security-best-practices",
        "cis-aws-foundations-benchmark",
        "cis-aws-foundations-benchmark-v3",
        "aws-resource-tagging-standard",
        "nist-800-53",
        "nist-800-171",
        "pci-dss",
      ], s)
    ])
    error_message = "See local.standard_arns in securityhub.tf for the supported names."
  }
}

variable "enable_config" {
  type        = bool
  description = "Enable AWS Config. Most Security Hub controls report NO_DATA without it."
  default     = true
}

variable "config_bucket_name" {
  type        = string
  description = "Override the generated AWS Config bucket name."
  default     = null
}

variable "enable_access_analyzer" {
  type        = bool
  description = "Create an IAM Access Analyzer for external access findings."
  default     = true
}

# --- Account settings ---

variable "manage_password_policy" {
  type        = bool
  description = "Set the IAM password policy. Only affects IAM users, which you should not have many of."
  default     = true
}

variable "password_minimum_length" {
  type        = number
  description = "Minimum IAM user password length."
  default     = 20

  validation {
    condition     = var.password_minimum_length >= 14
    error_message = "14 is the CIS minimum. 20 or more is better."
  }
}

variable "enable_ebs_encryption_by_default" {
  type        = bool
  description = "Encrypt every new EBS volume in this region."
  default     = true
}

variable "block_public_ami_sharing" {
  type        = bool
  description = "Stop new AMIs in this account being shared publicly."
  default     = true
}

variable "require_imdsv2_by_default" {
  type        = bool
  description = "Make IMDSv2 the regional default for new EC2 instances."
  default     = true
}

variable "block_s3_public_access" {
  type        = bool
  description = "Turn on all four account level S3 public access blocks."
  default     = true
}

variable "security_contact" {
  type = object({
    name          = string
    title         = string
    email_address = string
    phone_number  = string
  })
  description = "Account security alternate contact. Holds personal data, so prefer a shared mailbox and rota number, or set it outside Terraform."
  default     = null
}

# --- Cost guardrail ---

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly cost budget in USD. Set to null to skip."
  default     = null
}

variable "budget_notification_emails" {
  type        = list(string)
  description = "Addresses notified at 80 percent and 100 percent of forecast spend."
  default     = []
}

# --- CI access ---

variable "create_github_oidc_provider" {
  type        = bool
  description = "Create the GitHub Actions OIDC provider. One per account, so set false if another stack owns it."
  default     = false
}

variable "github_oidc_roles" {
  type = map(object({
    subjects            = list(string)
    managed_policy_arns = optional(list(string), [])
    inline_policy_json  = optional(string)
    max_session_seconds = optional(number, 3600)
  }))
  description = <<-EOT
    IAM roles GitHub Actions can assume. Keyed by role name.
    `subjects` are matched against the `sub` claim with StringLike, for example
    `repo:my-org/my-repo:ref:refs/heads/main` or `repo:my-org/my-repo:environment:prod`.
  EOT
  default     = {}

  validation {
    condition     = alltrue([for r in var.github_oidc_roles : length(r.subjects) > 0])
    error_message = "Every role needs at least one subject. An empty list would trust the whole of GitHub."
  }

  validation {
    condition = alltrue([
      for r in var.github_oidc_roles : alltrue([
        for s in r.subjects : startswith(s, "repo:") && !startswith(s, "repo:*")
      ])
    ])
    error_message = "Subjects must start with `repo:<org>/<repo>` so the trust is pinned to a repository."
  }
}

variable "config_include_global_resources" {
  type        = bool
  description = "Record global resources such as IAM. Leave true in one region only, otherwise you pay for the same items repeatedly."
  default     = true
}

variable "config_recording_frequency" {
  type        = string
  description = "CONTINUOUS records every change. DAILY records once a day and is a large cost saving in a busy account, at the price of findings that refresh daily."
  default     = "CONTINUOUS"

  validation {
    condition     = contains(["CONTINUOUS", "DAILY"], var.config_recording_frequency)
    error_message = "Must be CONTINUOUS or DAILY."
  }
}

variable "config_resource_types" {
  type        = list(string)
  description = <<-EOT
    Resource types to record. Empty records everything, which is correct and is
    also the largest line on the bill. A foundational subset that still feeds
    most Security Hub controls:

      ["AWS::IAM::User", "AWS::IAM::Role", "AWS::IAM::Policy", "AWS::IAM::Group",
       "AWS::S3::Bucket", "AWS::EC2::SecurityGroup", "AWS::EC2::Instance",
       "AWS::EC2::Volume", "AWS::EC2::VPC", "AWS::KMS::Key",
       "AWS::CloudTrail::Trail", "AWS::RDS::DBInstance", "AWS::Lambda::Function"]
  EOT
  default     = []
}

variable "guardduty_notify_min_severity" {
  type        = number
  description = "Lowest GuardDuty severity that sends a notification. 7 is HIGH, 4 is MEDIUM. Below 4 is noise."
  default     = 7

  validation {
    condition     = var.guardduty_notify_min_severity >= 1 && var.guardduty_notify_min_severity <= 10
    error_message = "GuardDuty severity runs from 1 to 10."
  }
}

variable "securityhub_notify_severities" {
  type        = list(string)
  description = "Security Hub severities that send a notification."
  default     = ["CRITICAL"]

  validation {
    condition = alltrue([
      for s in var.securityhub_notify_severities :
      contains(["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL"], s)
    ])
    error_message = "Valid severities are CRITICAL, HIGH, MEDIUM, LOW and INFORMATIONAL."
  }
}

variable "cost_anomaly_emails" {
  type        = list(string)
  description = "Addresses notified about cost anomalies. Setting this creates a Cost Explorer anomaly monitor, which is free and catches spikes a monthly budget never sees. Empty means no monitor."
  default     = []
}

variable "cost_anomaly_threshold_usd" {
  type        = number
  description = "Only alert when the unexpected spend reaches this many dollars."
  default     = 100
}
