locals {
  # Effective management group prefix (falls back to var.prefix)
  mg_prefix = var.management_group_prefix != "" ? var.management_group_prefix : var.prefix

  # Common tags applied to all Terraform-managed resources in this root
  common_tags = {
    managed-by  = "terraform"
    environment = "platform"
    cost-center = var.cost_center
    owner       = var.owner_email
    repo        = "Bootstrap-Azure-Terraform"
  }

  # Short region code used in resource names
  location_short = {
    "eastus"        = "eus"
    "eastus2"       = "eus2"
    "westus"        = "wus"
    "westus2"       = "wus2"
    "westus3"       = "wus3"
    "centralus"     = "cus"
    "northeurope"   = "neu"
    "westeurope"    = "weu"
    "uksouth"       = "uks"
    "ukwest"        = "ukw"
    "australiaeast" = "aue"
    "southeastasia" = "sea"
    "eastasia"      = "ea"
  }

  location_code = lookup(local.location_short, var.default_location, var.default_location)

  # Naming convention helper: {prefix}-{component}-{location_code}
  name = {
    log_analytics_rg        = "rg-${var.prefix}-logging-${local.location_code}"
    log_analytics_workspace = "log-${var.prefix}-platform-${local.location_code}"
    action_group            = "ag-${var.prefix}-platform-alerts"
  }
}
