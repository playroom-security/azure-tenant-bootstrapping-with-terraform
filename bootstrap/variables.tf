# ============================================================================
# Core Identity
# ============================================================================

variable "tenant_id" {
  type        = string
  description = "The Entra ID (Azure AD) tenant GUID. Found in Azure Portal → Entra ID → Overview."
}

variable "management_subscription_id" {
  type        = string
  description = "Subscription ID of the management/platform subscription used for shared services (Log Analytics, state storage, etc.)."
}

# ============================================================================
# Naming & Tagging
# ============================================================================

variable "prefix" {
  type        = string
  description = "Short organisation prefix (2–8 lowercase alphanumeric characters). Used in all resource names."

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.prefix))
    error_message = "prefix must be 2–8 lowercase alphanumeric characters."
  }
}

variable "default_location" {
  type        = string
  description = "Primary Azure region for platform resources (e.g. 'eastus', 'westeurope')."
  default     = "eastus"
}

variable "cost_center" {
  type        = string
  description = "Cost centre code applied as a tag to all platform resources."
}

variable "owner_email" {
  type        = string
  description = "Email address of the platform team owner, applied as a tag to all platform resources."
}

# ============================================================================
# Management Groups
# ============================================================================

variable "management_group_prefix" {
  type        = string
  description = "Override for the management group name prefix. Defaults to var.prefix."
  default     = ""
}

# ============================================================================
# Policies
# ============================================================================

variable "allowed_locations" {
  type        = list(string)
  description = "List of Azure regions where resources are allowed to be deployed. Applied as a Deny policy at root MG."
  default     = ["eastus", "eastus2", "westus2"]
}

variable "policy_enforcement_mode" {
  type        = string
  description = "Policy enforcement mode. Use 'Default' in production, 'DoNotEnforce' during initial rollout."
  default     = "Default"

  validation {
    condition     = contains(["Default", "DoNotEnforce"], var.policy_enforcement_mode)
    error_message = "policy_enforcement_mode must be 'Default' or 'DoNotEnforce'."
  }
}

# ============================================================================
# RBAC
# ============================================================================

variable "platform_admin_group_id" {
  type        = string
  description = "Entra ID group object ID for the platform / cloud infrastructure admin team. Gets Contributor at the Platform management group."
  default     = ""
}

variable "developer_group_id" {
  type        = string
  description = "Entra ID group object ID for application developers. Gets Contributor at Landing Zones MG, Reader at Platform MG."
  default     = ""
}

# ============================================================================
# Logging
# ============================================================================

variable "log_analytics_retention_days" {
  type        = number
  description = "Log Analytics workspace data retention in days."
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "log_analytics_retention_days must be between 30 and 730."
  }
}

# ============================================================================
# Budget
# ============================================================================

variable "budget_amount_usd" {
  type        = number
  description = "Monthly budget limit in USD for the management subscription."
  default     = 500
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "List of email addresses to notify when budget thresholds are breached."
}
