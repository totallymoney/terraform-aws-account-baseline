# A monthly budget never fires on a 50 dollar a day spike in an account
# budgeted at 5000 a month. Anomaly detection does, and it costs nothing.
#
# Cost Explorer is a global service. The SDK always reaches it through
# us-east-1, so these resources do not take a region and work whatever region
# the provider is configured for.

locals {
  # AWS rejects a subscription with no subscribers, and a monitor nobody hears
  # about is pointless, so the recipient list is the switch. No separate
  # enable flag, because that would allow a combination that cannot work.
  cost_anomaly = length(var.cost_anomaly_emails) > 0 ? 1 : 0
}

resource "aws_ce_anomaly_monitor" "service" {
  count = local.cost_anomaly

  name              = "${var.name}-service-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
  tags              = local.tags
}

resource "aws_ce_anomaly_subscription" "this" {
  count = local.cost_anomaly

  name             = "${var.name}-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.service[0].arn]
  tags             = local.tags

  dynamic "subscriber" {
    for_each = toset(var.cost_anomaly_emails)

    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }

  # Only alert when the unexpected spend is worth someone's attention.
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.cost_anomaly_threshold_usd)]
    }
  }
}

