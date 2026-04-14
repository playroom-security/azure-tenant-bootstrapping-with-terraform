# Remote state backend — Azure Blob Storage
#
# IMPORTANT: Update storage_account_name with the value printed by scripts/bootstrap.sh
# before running terraform init for the first time.
#
# Authentication uses OIDC (use_oidc = true) — no storage account key or SAS token.
# The Terraform service principal must have "Storage Blob Data Contributor" on this account.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-mgmt-eastus"
    storage_account_name = "REPLACE_WITH_SA_NAME_FROM_BOOTSTRAP"
    container_name       = "bootstrap"
    key                  = "bootstrap.tfstate"
    use_oidc             = true
  }
}
