# Stage 2. The account baseline.
#
# Run once per account, in your main region. If you operate in more than one
# region, apply a second copy with `enable_cloudtrail = false` and
# `config_include_global_resources = false` so you are not paying twice for the
# same records.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Owner       = "platform"
      Environment = "shared"
    }
  }
}

module "baseline" {
  source = "../../"

  name = "example"

  alarm_email        = "security-alerts@example.com"
  monthly_budget_usd = 500

  budget_notification_emails = ["finops@example.com"]

  # Holds personal data. Prefer a shared mailbox and an on call number.
  security_contact = {
    name          = "Security"
    title         = "Security contact"
    email_address = "security@example.com"
    phone_number  = "+447700900000"
  }

  # One provider per account. Set false if another stack already made it.
  create_github_oidc_provider = true

  github_oidc_roles = {
    "example-deploy" = {
      subjects = [
        "repo:my-org/my-service:ref:refs/heads/main",
        "repo:my-org/my-service:environment:production",
      ]
      inline_policy_json = data.aws_iam_policy_document.deploy.json
    }
  }
}

# Scope this to what your pipeline actually deploys. A wildcard here undoes
# most of the value of using OIDC in the first place.
data "aws_iam_policy_document" "deploy" {
  statement {
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/example-*-task*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

output "github_oidc_role_arns" {
  value = module.baseline.github_oidc_role_arns
}

output "security_alarm_topic_arn" {
  value = module.baseline.security_alarm_topic_arn
}
