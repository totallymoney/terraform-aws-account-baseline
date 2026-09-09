# Regional and account wide defaults. Each of these is one API call that closes
# a whole class of mistake, which is why they are on by default.

resource "aws_s3_account_public_access_block" "this" {
  count = var.block_s3_public_access ? 1 : 0

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ebs_encryption_by_default" "this" {
  count = var.enable_ebs_encryption_by_default ? 1 : 0

  enabled = true
}

resource "aws_ec2_image_block_public_access" "this" {
  count = var.block_public_ami_sharing ? 1 : 0

  state = "block-new-sharing"
}

# Hop limit 2 so a container on EC2 can still reach the metadata service.
resource "aws_ec2_instance_metadata_defaults" "this" {
  count = var.require_imdsv2_by_default ? 1 : 0

  http_tokens                 = "required"
  http_put_response_hop_limit = 2
}

# AWS emails this contact about abuse and exposed credentials. Without it the
# mail goes to the root address, which usually nobody reads.
resource "aws_account_alternate_contact" "security" {
  count = var.security_contact != null ? 1 : 0

  alternate_contact_type = "SECURITY"
  name                   = var.security_contact.name
  title                  = var.security_contact.title
  email_address          = var.security_contact.email_address
  phone_number           = var.security_contact.phone_number
}

resource "aws_budgets_budget" "monthly" {
  count = var.monthly_budget_usd != null ? 1 : 0

  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }
}
