# =============================================================================
# Module: Management Groups
#
# Creates the CAF Enterprise Scale management group hierarchy:
#
#   Tenant Root Group
#   ├── {prefix}-platform
#   │   ├── {prefix}-platform-management
#   │   ├── {prefix}-platform-connectivity
#   │   └── {prefix}-platform-identity
#   ├── {prefix}-landingzones
#   │   ├── {prefix}-landingzones-corp          (production)
#   │   └── {prefix}-landingzones-corpnonprod   (non-production)
#   ├── {prefix}-sandbox
#   └── {prefix}-decommissioned
# =============================================================================

# ---------------------------------------------------------------------------
# Tier 1 — Children of Tenant Root Group
# ---------------------------------------------------------------------------

resource "azurerm_management_group" "platform" {
  name                       = "${var.prefix}-platform"
  display_name               = "${var.prefix} Platform"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"
}

resource "azurerm_management_group" "landingzones" {
  name                       = "${var.prefix}-landingzones"
  display_name               = "${var.prefix} Landing Zones"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"
}

resource "azurerm_management_group" "sandbox" {
  name                       = "${var.prefix}-sandbox"
  display_name               = "${var.prefix} Sandbox"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"
}

resource "azurerm_management_group" "decommissioned" {
  name                       = "${var.prefix}-decommissioned"
  display_name               = "${var.prefix} Decommissioned"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"
}

# ---------------------------------------------------------------------------
# Tier 2 — Platform children
# ---------------------------------------------------------------------------

resource "azurerm_management_group" "platform_management" {
  name                       = "${var.prefix}-platform-management"
  display_name               = "${var.prefix} Platform Management"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "platform_connectivity" {
  name                       = "${var.prefix}-platform-connectivity"
  display_name               = "${var.prefix} Platform Connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "platform_identity" {
  name                       = "${var.prefix}-platform-identity"
  display_name               = "${var.prefix} Platform Identity"
  parent_management_group_id = azurerm_management_group.platform.id
}

# ---------------------------------------------------------------------------
# Tier 2 — Landing Zone children
# ---------------------------------------------------------------------------

resource "azurerm_management_group" "lz_corp" {
  name                       = "${var.prefix}-landingzones-corp"
  display_name               = "${var.prefix} Corp (Production)"
  parent_management_group_id = azurerm_management_group.landingzones.id
}

resource "azurerm_management_group" "lz_corp_nonprod" {
  name                       = "${var.prefix}-landingzones-corpnonprod"
  display_name               = "${var.prefix} Corp Non-Production"
  parent_management_group_id = azurerm_management_group.landingzones.id
}
