output "policy_assignment_ids" {
  description = "Map of policy assignment names to their resource IDs."
  value = {
    require_tag_environment  = azurerm_management_group_policy_assignment.require_tag_environment.id
    require_tag_owner        = azurerm_management_group_policy_assignment.require_tag_owner.id
    require_tag_cost_center  = azurerm_management_group_policy_assignment.require_tag_cost_center.id
    allowed_locations        = azurerm_management_group_policy_assignment.allowed_locations.id
    allowed_locations_rg     = azurerm_management_group_policy_assignment.allowed_locations_rg.id
    require_https_storage    = azurerm_management_group_policy_assignment.require_https_storage.id
    audit_unencrypted_disks  = azurerm_management_group_policy_assignment.audit_unencrypted_disks.id
    deny_public_ip           = azurerm_management_group_policy_assignment.deny_public_ip.id
    defender_for_cloud       = azurerm_management_group_policy_assignment.defender_for_cloud.id
  }
}
