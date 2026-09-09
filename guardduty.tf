resource "aws_guardduty_detector" "this" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  tags                         = local.tags
}

resource "aws_guardduty_detector_feature" "this" {
  for_each = var.enable_guardduty ? toset(var.guardduty_features) : []

  detector_id = aws_guardduty_detector.this[0].id
  name        = each.key
  status      = "ENABLED"
}
