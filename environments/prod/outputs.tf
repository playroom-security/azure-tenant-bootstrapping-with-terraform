output "corp_management_group_id" {
  description = "Resource ID of the Corp (production) management group."
  value       = local.corp_mg_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the centralised Log Analytics workspace."
  value       = local.log_analytics_ws_id
}
