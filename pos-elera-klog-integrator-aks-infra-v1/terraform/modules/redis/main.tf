resource "azurerm_redis_cache" "this" {
  name                = "redis-${var.app_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.capacity
  family              = var.family
  sku_name            = var.sku_name
  minimum_tls_version         = "1.2"
  enable_non_ssl_port         = false
  public_network_access_enabled = false
  tags                        = var.tags
}

resource "azurerm_key_vault_secret" "redis_url" {
  name            = "redis-url"
  value           = "rediss://:${azurerm_redis_cache.this.primary_access_key}@${azurerm_redis_cache.this.hostname}:${azurerm_redis_cache.this.ssl_port}"
  key_vault_id    = var.keyvault_id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h")

  depends_on = [var.keyvault_rbac_ready]

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
