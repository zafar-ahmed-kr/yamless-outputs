output "hostname"       { value = azurerm_redis_cache.this.hostname }
output "kv_secret_name" { value = azurerm_key_vault_secret.redis_url.name }
