# All authentication values (ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID)
# are injected as environment variables by GitHub Actions via OIDC.
# No client_secret is used anywhere in this configuration.

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy               = false
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_secrets_on_destroy      = false
      recover_soft_deleted_secrets               = true
    }
  }

  use_oidc        = true
  subscription_id = var.management_subscription_id
  tenant_id       = var.tenant_id
}

# azuread provider for Entra ID resources (groups, applications, etc.)
provider "azuread" {
  use_oidc  = true
  tenant_id = var.tenant_id
}
