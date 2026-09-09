# Password policy only binds IAM users. Prefer IAM Identity Center and keep the
# user count at zero, but set the policy anyway so a user created in a hurry is
# not created with a weak password.
resource "aws_iam_account_password_policy" "this" {
  count = var.manage_password_policy ? 1 : 0

  minimum_password_length        = var.password_minimum_length
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24

  # No max_password_age. CIS v3.0 dropped forced rotation, in line with
  # NIST SP 800-63B.
}

resource "aws_accessanalyzer_analyzer" "external" {
  count = var.enable_access_analyzer ? 1 : 0

  analyzer_name = "${var.name}-external-access"
  type          = "ACCOUNT"
  tags          = local.tags
}
