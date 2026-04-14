variable "tenant_id" {
  type        = string
  description = "The Entra ID tenant GUID. Used as the parent of the top-level management groups."
}

variable "prefix" {
  type        = string
  description = "Short organisation prefix used in management group display names and IDs."
}
