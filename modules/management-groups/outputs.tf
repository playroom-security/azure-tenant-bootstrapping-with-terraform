output "management_group_ids" {
  description = "Map of management group logical names to their full resource IDs."
  value = {
    "platform"                   = azurerm_management_group.platform.id
    "platform-management"        = azurerm_management_group.platform_management.id
    "platform-connectivity"      = azurerm_management_group.platform_connectivity.id
    "platform-identity"          = azurerm_management_group.platform_identity.id
    "landingzones"               = azurerm_management_group.landingzones.id
    "landingzones-corp"          = azurerm_management_group.lz_corp.id
    "landingzones-corpnonprod"   = azurerm_management_group.lz_corp_nonprod.id
    "sandbox"                    = azurerm_management_group.sandbox.id
    "decommissioned"             = azurerm_management_group.decommissioned.id
  }
}

output "root_scope" {
  description = "Tenant root management group scope URI."
  value       = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"
}
