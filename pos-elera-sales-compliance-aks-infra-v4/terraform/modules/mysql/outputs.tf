output "fqdn"          { value = azurerm_mysql_flexible_server.this.fqdn }
output "database_name" { value = azurerm_mysql_flexible_database.this.name }
output "kv_secret_name" { value = azurerm_key_vault_secret.db_url.name }
