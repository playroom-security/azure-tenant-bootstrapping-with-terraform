output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.platform.id
}

output "workspace_primary_key" {
  description = "Primary shared key of the Log Analytics workspace (sensitive)."
  value       = azurerm_log_analytics_workspace.platform.primary_shared_key
  sensitive   = true
}

output "workspace_customer_id" {
  description = "Customer ID (workspace GUID) of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.platform.workspace_id
}

output "action_group_id" {
  description = "Resource ID of the platform monitoring action group."
  value       = azurerm_monitor_action_group.platform.id
}
