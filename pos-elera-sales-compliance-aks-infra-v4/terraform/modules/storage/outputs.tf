output "account_name"    { value = azurerm_storage_account.this.name }
output "account_id"      { value = azurerm_storage_account.this.id }
output "container_name"  { value = azurerm_storage_container.main.name }
output "kv_secret_name"  { value = azurerm_key_vault_secret.storage_connection.name }
