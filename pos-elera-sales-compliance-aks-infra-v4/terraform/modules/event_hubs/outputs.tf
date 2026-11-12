output "namespace_name" { value = azurerm_eventhub_namespace.this.name }
output "eventhub_name"  { value = azurerm_eventhub.this.name }
output "kv_secret_name" { value = azurerm_key_vault_secret.eventhubs_connection_string.name }
