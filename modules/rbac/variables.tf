variable "management_group_ids" {
  type        = map(string)
  description = "Map of management group logical names to resource IDs (from the management-groups module)."
}

variable "platform_admin_group_id" {
  type        = string
  description = "Entra ID group object ID for platform/cloud infrastructure admins. Receives Contributor at Platform MG. Leave empty to skip."
  default     = ""
}

variable "developer_group_id" {
  type        = string
  description = "Entra ID group object ID for application developers. Receives Contributor at Landing Zones MG, Reader at Platform MG. Leave empty to skip."
  default     = ""
}
