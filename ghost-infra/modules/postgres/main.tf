resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*-_=+"
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = "psql-${var.app_name}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = "16"
  administrator_login           = var.app_name
  administrator_password        = random_password.db.result
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false
  ssl_enforcement_enabled       = true
  tags                          = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.app_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Store the connection string in Key Vault — app reads it via managed identity
resource "azurerm_key_vault_secret" "db_url" {
  name            = "database-url"
  value           = "postgresql://${var.app_name}:${random_password.db.result}@${azurerm_postgresql_flexible_server.this.fqdn}:5432/${var.app_name}?sslmode=require"
  key_vault_id    = var.keyvault_id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year; rotate via pipeline

  depends_on = [var.keyvault_rbac_ready]

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
