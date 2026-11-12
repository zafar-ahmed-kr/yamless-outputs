output "account_name"   { value = azurerm_cosmosdb_account.this.name }
output "kv_secret_name" { value = azurerm_key_vault_secret.mongo_url.name }
