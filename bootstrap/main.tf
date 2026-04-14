# =============================================================================
# Bootstrap Root Module
#
# Builds the tenant-level foundations following CAF Enterprise Scale:
#   1. Management Group hierarchy
#   2. Azure Policy assignments
#   3. RBAC at management group scope
#   4. Centralised logging (Log Analytics)
#   5. Budget alerts on the management subscription
# =============================================================================

# -----------------------------------------------------------------------------
# Resource Group for platform logging (managed by Terraform)
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "logging" {
  name     = local.name.log_analytics_rg
  location = var.default_location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# Module: Management Group Hierarchy
# -----------------------------------------------------------------------------
module "management_groups" {
  source = "../modules/management-groups"

  tenant_id = var.tenant_id
  prefix    = local.mg_prefix
}

# -----------------------------------------------------------------------------
# Module: Azure Policy Assignments
# -----------------------------------------------------------------------------
module "policy" {
  source = "../modules/policy"

  tenant_id               = var.tenant_id
  management_group_ids    = module.management_groups.management_group_ids
  allowed_locations       = var.allowed_locations
  enforcement_mode        = var.policy_enforcement_mode

  depends_on = [module.management_groups]
}

# -----------------------------------------------------------------------------
# Module: RBAC at Management Group scope
# -----------------------------------------------------------------------------
module "rbac" {
  source = "../modules/rbac"

  management_group_ids    = module.management_groups.management_group_ids
  platform_admin_group_id = var.platform_admin_group_id
  developer_group_id      = var.developer_group_id

  depends_on = [module.management_groups]
}

# -----------------------------------------------------------------------------
# Module: Centralised Logging
# -----------------------------------------------------------------------------
module "logging" {
  source = "../modules/logging"

  resource_group_name          = azurerm_resource_group.logging.name
  location                     = var.default_location
  workspace_name               = local.name.log_analytics_workspace
  action_group_name            = local.name.action_group
  log_retention_days           = var.log_analytics_retention_days
  alert_emails                 = var.budget_alert_emails
  management_group_ids         = module.management_groups.management_group_ids
  tags                         = local.common_tags

  depends_on = [azurerm_resource_group.logging]
}

# -----------------------------------------------------------------------------
# Module: Budget Alerts
# -----------------------------------------------------------------------------
module "budget" {
  source = "../modules/budget"

  subscription_id   = var.management_subscription_id
  budget_amount_usd = var.budget_amount_usd
  action_group_id   = module.logging.action_group_id
  prefix            = var.prefix

  depends_on = [module.logging]
}
