resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*-_=+"
}

resource "azurerm_mysql_flexible_server" "this" {
  name                          = "mysql-${var.app_name}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  administrator_login           = var.app_name
  administrator_password        = random_password.db.result
  sku_name                      = "B_Standard_B1ms"
  version                       = "8.0.21"
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_mysql_flexible_database" "this" {
  name                = var.app_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# Store the connection string in Key Vault — app reads it via managed identity
resource "azurerm_key_vault_secret" "db_url" {
  name            = "database-url"
  value           = "mysql+pymysql://${var.app_name}:${random_password.db.result}@${azurerm_mysql_flexible_server.this.fqdn}:3306/${var.app_name}?ssl_ca=/etc/ssl/certs/ca-certificates.crt"
  key_vault_id    = var.keyvault_id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year; rotate via pipeline

  depends_on = [var.keyvault_rbac_ready]

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
