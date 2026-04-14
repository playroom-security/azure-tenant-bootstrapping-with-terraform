provider "azurerm" {
  features {}
  use_oidc        = true
  subscription_id = var.nonprod_subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  use_oidc  = true
  tenant_id = var.tenant_id
}
