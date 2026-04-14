terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-mgmt-eastus"
    storage_account_name = "REPLACE_WITH_SA_NAME_FROM_BOOTSTRAP"
    container_name       = "prod"
    key                  = "prod.tfstate"
    use_oidc             = true
  }
}
