# =============================================================================
# Module: RBAC — Role Assignments at Management Group Scope
#
# Role assignments here grant broad, platform-level access.
# Workload-specific role assignments belong in environment roots, not here.
# =============================================================================

# ---------------------------------------------------------------------------
# Platform Admins → Contributor at Platform Management Group
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "platform_admin_contributor" {
  count = var.platform_admin_group_id != "" ? 1 : 0

  scope                = var.management_group_ids["platform"]
  role_definition_name = "Contributor"
  principal_id         = var.platform_admin_group_id
  description          = "Platform admin team — full control over platform management groups."

  # Prevent accidental removal by requiring explicit skip_service_principal_aad_check = false
  skip_service_principal_aad_check = false
}

# ---------------------------------------------------------------------------
# Platform Admins → Reader at Landing Zones (visibility without write access)
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "platform_admin_reader_lz" {
  count = var.platform_admin_group_id != "" ? 1 : 0

  scope                = var.management_group_ids["landingzones"]
  role_definition_name = "Reader"
  principal_id         = var.platform_admin_group_id
  description          = "Platform admin team — read access to landing zones for governance visibility."

  skip_service_principal_aad_check = false
}

# ---------------------------------------------------------------------------
# Developers → Contributor at Landing Zones Management Group
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "developer_contributor_lz" {
  count = var.developer_group_id != "" ? 1 : 0

  scope                = var.management_group_ids["landingzones"]
  role_definition_name = "Contributor"
  principal_id         = var.developer_group_id
  description          = "Developers — deploy workloads within landing zones."

  skip_service_principal_aad_check = false
}

# ---------------------------------------------------------------------------
# Developers → Reader at Platform Management Group
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "developer_reader_platform" {
  count = var.developer_group_id != "" ? 1 : 0

  scope                = var.management_group_ids["platform"]
  role_definition_name = "Reader"
  principal_id         = var.developer_group_id
  description          = "Developers — read access to platform resources for troubleshooting."

  skip_service_principal_aad_check = false
}
