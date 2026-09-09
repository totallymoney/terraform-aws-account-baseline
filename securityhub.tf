# Security Hub is the reporting layer. It does not enforce anything, so read it
# rather than assuming a green account means a safe one.

resource "aws_securityhub_account" "this" {
  count = var.enable_securityhub ? 1 : 0

  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

locals {
  standard_arns = {
    aws-foundational-security-best-practices = "arn:${local.partition}:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
    cis-aws-foundations-benchmark            = "arn:${local.partition}:securityhub:${local.region}::standards/cis-aws-foundations-benchmark/v/3.0.0"
    nist-800-53                              = "arn:${local.partition}:securityhub:${local.region}::standards/nist-800-53/v/5.0.0"
    pci-dss                                  = "arn:${local.partition}:securityhub:${local.region}::standards/pci-dss/v/4.0.1"
  }
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each = var.enable_securityhub ? toset(var.securityhub_standards) : []

  standards_arn = local.standard_arns[each.key]

  depends_on = [aws_securityhub_account.this]
}
