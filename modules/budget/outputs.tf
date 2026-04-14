output "budget_id" {
  description = "Resource ID of the subscription budget."
  value       = azurerm_consumption_budget_subscription.management.id
}

output "budget_name" {
  description = "Name of the subscription budget."
  value       = azurerm_consumption_budget_subscription.management.name
}
