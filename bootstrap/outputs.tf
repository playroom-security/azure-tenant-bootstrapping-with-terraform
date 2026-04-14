# =============================================================================
# Bootstrap Outputs
#
# These outputs are consumed by environment roots (environments/prod, nonprod)
# via the terraform_remote_state data source.
# =============================================================================

output "tenant_id" {
  description = "The Entra ID tenant GUID."
  value       = var.tenant_id
}

output "management_subscription_id" {
  description = "The management subscription ID."
  value       = var.management_subscription_id
}

# Management Groups
output "management_group_ids" {
  description = "Map of management group friendly names to their full resource IDs."
  value       = module.management_groups.management_group_ids
}

output "platform_management_group_id" {
  description = "Resource ID of the Platform management group."
  value       = module.management_groups.management_group_ids["platform"]
}

output "landing_zones_management_group_id" {
  description = "Resource ID of the Landing Zones management group."
  value       = module.management_groups.management_group_ids["landingzones"]
}

output "corp_prod_management_group_id" {
  description = "Resource ID of the Corp (production) landing zone management group."
  value       = module.management_groups.management_group_ids["landingzones-corp"]
}

output "corp_nonprod_management_group_id" {
  description = "Resource ID of the Corp Non-Prod landing zone management group."
  value       = module.management_groups.management_group_ids["landingzones-corpnonprod"]
}

# Logging
output "log_analytics_workspace_id" {
  description = "Resource ID of the centralised Log Analytics workspace."
  value       = module.logging.workspace_id
}

output "log_analytics_workspace_key" {
  description = "Primary shared key of the Log Analytics workspace."
  value       = module.logging.workspace_primary_key
  sensitive   = true
}

output "action_group_id" {
  description = "Resource ID of the platform monitoring action group."
  value       = module.logging.action_group_id
}
