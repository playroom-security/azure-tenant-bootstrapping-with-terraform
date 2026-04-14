variable "tenant_id" {
  type        = string
  description = "Entra ID tenant GUID. Used to construct the root management group scope."
}

variable "management_group_ids" {
  type        = map(string)
  description = "Map of management group logical names to resource IDs (from the management-groups module)."
}

variable "allowed_locations" {
  type        = list(string)
  description = "List of allowed Azure regions enforced by policy."
}

variable "enforcement_mode" {
  type        = string
  description = "Policy enforcement mode: 'Default' (enforce) or 'DoNotEnforce' (audit only)."
  default     = "Default"
}
