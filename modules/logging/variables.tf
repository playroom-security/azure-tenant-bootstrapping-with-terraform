variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where the Log Analytics workspace will be created."
}

variable "location" {
  type        = string
  description = "Azure region for the Log Analytics workspace."
}

variable "workspace_name" {
  type        = string
  description = "Name of the Log Analytics workspace."
}

variable "action_group_name" {
  type        = string
  description = "Name of the Azure Monitor action group for alerting."
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics workspace data retention period in days (30–730)."
  default     = 30
}

variable "alert_emails" {
  type        = list(string)
  description = "Email addresses to notify on alerts."
}

variable "management_group_ids" {
  type        = map(string)
  description = "Map of management group logical names to resource IDs."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
