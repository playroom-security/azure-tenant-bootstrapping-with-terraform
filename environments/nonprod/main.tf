# =============================================================================
# Non-Production Landing Zone Root
#
# Reads bootstrap outputs (management group IDs, Log Analytics workspace)
# via remote state and uses them to scope landing zone workloads.
#
# Add workload module calls below as your non-prod infrastructure grows.
# =============================================================================

# Read outputs from the bootstrap root
data "terraform_remote_state" "bootstrap" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.bootstrap_state_resource_group
    storage_account_name = var.bootstrap_state_storage_account
    container_name       = "bootstrap"
    key                  = "bootstrap.tfstate"
    use_oidc             = true
  }
}

locals {
  bootstrap = data.terraform_remote_state.bootstrap.outputs

  # Commonly referenced values from bootstrap
  corp_nonprod_mg_id    = local.bootstrap.corp_nonprod_management_group_id
  log_analytics_ws_id   = local.bootstrap.log_analytics_workspace_id
  action_group_id       = local.bootstrap.action_group_id
}

# ---------------------------------------------------------------------------
# Add non-prod landing zone modules here
# ---------------------------------------------------------------------------
