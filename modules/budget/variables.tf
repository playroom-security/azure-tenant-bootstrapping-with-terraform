variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to attach the budget to."
}

variable "budget_amount_usd" {
  type        = number
  description = "Monthly budget limit in USD."
}

variable "action_group_id" {
  type        = string
  description = "Resource ID of the Azure Monitor action group to notify when thresholds are breached."
}

variable "prefix" {
  type        = string
  description = "Short organisation prefix used in the budget name."
}
