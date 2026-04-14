output "platform_admin_assignment_id" {
  description = "Resource ID of the platform admin Contributor assignment (empty string if not configured)."
  value       = length(azurerm_role_assignment.platform_admin_contributor) > 0 ? azurerm_role_assignment.platform_admin_contributor[0].id : ""
}

output "developer_assignment_id" {
  description = "Resource ID of the developer Contributor assignment at Landing Zones (empty string if not configured)."
  value       = length(azurerm_role_assignment.developer_contributor_lz) > 0 ? azurerm_role_assignment.developer_contributor_lz[0].id : ""
}
