# =============================================================================
# Module: Centralised Logging
#
# Creates:
#   - Log Analytics Workspace (platform-wide log sink)
#   - Azure Monitor Action Group (email notifications for alerts/budgets)
#   - Diagnostic settings forwarding management group activity logs to workspace
# =============================================================================

# ---------------------------------------------------------------------------
# Log Analytics Workspace
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "platform" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  # Daily cap to prevent runaway ingestion costs (adjust as needed)
  daily_quota_gb = 5

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Azure Monitor Action Group (used by budget alerts and future metric alerts)
# ---------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "platform" {
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = "platform"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = "email-${index(var.alert_emails, email_receiver.value)}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# ---------------------------------------------------------------------------
# Diagnostic Settings — Management Group Activity Logs → Log Analytics
#
# Sends tenant-level activity log events (policy changes, RBAC changes,
# management group operations) to the central workspace.
# ---------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "platform_mg" {
  name               = "diag-platform-mg-to-law"
  target_resource_id = var.management_group_ids["platform"]

  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Policy"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "Alert"
  }
}

resource "azurerm_monitor_diagnostic_setting" "landingzones_mg" {
  name               = "diag-lz-mg-to-law"
  target_resource_id = var.management_group_ids["landingzones"]

  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Policy"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "Alert"
  }
}
