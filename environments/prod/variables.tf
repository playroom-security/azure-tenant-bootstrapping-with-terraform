variable "tenant_id" {
  type        = string
  description = "Entra ID tenant GUID."
}

variable "prod_subscription_id" {
  type        = string
  description = "Azure subscription ID for the production landing zone."
}

variable "bootstrap_state_storage_account" {
  type        = string
  description = "Name of the storage account holding the bootstrap Terraform state (for remote_state lookups)."
}

variable "bootstrap_state_resource_group" {
  type        = string
  description = "Resource group of the bootstrap state storage account."
  default     = "rg-terraform-state-mgmt-eastus"
}
