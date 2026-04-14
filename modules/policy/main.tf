# =============================================================================
# Module: Azure Policy Assignments
#
# All assignments reference built-in policy definitions by their well-known
# GUID so no custom policy definitions need to be maintained.
#
# Assignment scopes follow the principle of least scope:
#   - Root MG  : tenant-wide governance baselines (tags, locations)
#   - LZ MG    : workload-specific controls (HTTPS, disk encryption)
#   - Corp MG  : production-specific strict controls (no public IPs)
#   - Mgmt MG  : Defender for Cloud enablement
# =============================================================================

locals {
  root_scope    = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"
  lz_scope      = var.management_group_ids["landingzones"]
  corp_scope    = var.management_group_ids["landingzones-corp"]
  mgmt_scope    = var.management_group_ids["platform-management"]
}

# ---------------------------------------------------------------------------
# Root MG — Tag enforcement (Deny resources missing required tags)
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "require_tag_environment" {
  name                 = "require-tag-environment"
  display_name         = "Require 'environment' tag on resources"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  management_group_id  = local.root_scope
  enforce              = var.enforcement_mode == "Default"

  parameters = jsonencode({
    tagName = { value = "environment" }
  })
}

resource "azurerm_management_group_policy_assignment" "require_tag_owner" {
  name                 = "require-tag-owner"
  display_name         = "Require 'owner' tag on resources"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  management_group_id  = local.root_scope
  enforce              = var.enforcement_mode == "Default"

  parameters = jsonencode({
    tagName = { value = "owner" }
  })
}

resource "azurerm_management_group_policy_assignment" "require_tag_cost_center" {
  name                 = "require-tag-cost-center"
  display_name         = "Require 'cost-center' tag on resources"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  management_group_id  = local.root_scope
  enforce              = var.enforcement_mode == "Default"

  parameters = jsonencode({
    tagName = { value = "cost-center" }
  })
}

# ---------------------------------------------------------------------------
# Root MG — Allowed locations (Deny resources outside approved regions)
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations for resources"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  management_group_id  = local.root_scope
  enforce              = var.enforcement_mode == "Default"

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

resource "azurerm_management_group_policy_assignment" "allowed_locations_rg" {
  name                 = "allowed-locations-rg"
  display_name         = "Allowed locations for resource groups"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988"
  management_group_id  = local.root_scope
  enforce              = var.enforcement_mode == "Default"

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

# ---------------------------------------------------------------------------
# Landing Zones MG — Require HTTPS on Storage Accounts
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "require_https_storage" {
  name                 = "require-https-storage"
  display_name         = "Secure transfer to storage accounts should be enabled"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  management_group_id  = local.lz_scope
  enforce              = var.enforcement_mode == "Default"
}

# ---------------------------------------------------------------------------
# Landing Zones MG — Audit unencrypted OS disks
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "audit_unencrypted_disks" {
  name                 = "audit-unencrypted-disks"
  display_name         = "Disk encryption should be applied on virtual machines"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d"
  management_group_id  = local.lz_scope
  enforce              = false  # Audit only — never block disk creation
}

# ---------------------------------------------------------------------------
# Corp (Production) MG — Deny public IP address creation
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  name                 = "deny-public-ip"
  display_name         = "Not allowed resource types - Public IP"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
  management_group_id  = local.corp_scope
  enforce              = var.enforcement_mode == "Default"

  parameters = jsonencode({
    listOfResourceTypesNotAllowed = { value = ["microsoft.network/publicipaddresses"] }
  })
}

# ---------------------------------------------------------------------------
# Platform Management MG — Enable Microsoft Defender for Cloud (DINE)
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "defender_for_cloud" {
  name                 = "enable-defender-cloud"
  display_name         = "Configure Azure Defender to be enabled on Subscriptions"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/ac076320-ddcf-4066-b451-6154267e8ad2"
  management_group_id  = local.mgmt_scope
  enforce              = var.enforcement_mode == "Default"

  identity {
    type = "SystemAssigned"
  }

  location = "eastus"
}

# Grant the policy assignment's managed identity the required role for DINE
resource "azurerm_role_assignment" "defender_policy_contributor" {
  scope                = local.mgmt_scope
  role_definition_name = "Security Admin"
  principal_id         = azurerm_management_group_policy_assignment.defender_for_cloud.identity[0].principal_id
}
