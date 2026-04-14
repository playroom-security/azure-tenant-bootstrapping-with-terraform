# =============================================================================
# Module: Subscription Budget Alerts
#
# Creates a monthly budget on the management subscription with three alert
# thresholds: 50%, 80%, and 100% of the configured amount.
#
# Notifications fire on both actual and forecast spend.
# =============================================================================

locals {
  # Budget time window: start at the first of the current month, end 1 year out
  budget_start = "${formatdate("YYYY-MM", timestamp())}-01"
  budget_end   = "${tonumber(formatdate("YYYY", timestamp())) + 1}-${formatdate("MM-01", timestamp())}"
}

resource "azurerm_consumption_budget_subscription" "management" {
  name            = "budget-${var.prefix}-mgmt-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"

  amount     = var.budget_amount_usd
  time_grain = "Monthly"

  time_period {
    start_date = "${local.budget_start}T00:00:00Z"
    end_date   = "${local.budget_end}T00:00:00Z"
  }

  # Alert at 50% actual spend
  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_groups = [var.action_group_id]
  }

  # Alert at 80% actual spend
  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_groups = [var.action_group_id]
  }

  # Alert at 100% actual spend
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_groups = [var.action_group_id]
  }

  # Alert at 90% forecasted spend (warn before hitting limit)
  notification {
    enabled        = true
    threshold      = 90
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_groups = [var.action_group_id]
  }
}
