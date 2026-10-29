output "app_url" {
  description = "Public URL of the deployed Container App."
  value       = "https://${module.container_app.fqdn}"
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "keyvault_name" {
  value = module.keyvault.name
}

output "managed_identity_client_id" {
  description = "Client ID to set as AZURE_CLIENT_ID in local development."
  value       = module.managed_identity.client_id
}

output "postgres_fqdn" {
  value = module.postgres.fqdn
}

output "storage_account_name" {
  value = module.storage.account_name
}

