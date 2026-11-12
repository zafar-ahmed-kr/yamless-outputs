output "namespace_name" { value = azurerm_servicebus_namespace.this.name }
output "queue_name"     { value = azurerm_servicebus_queue.main.name }
output "kv_secret_name" { value = azurerm_key_vault_secret.sb_connection.name }
