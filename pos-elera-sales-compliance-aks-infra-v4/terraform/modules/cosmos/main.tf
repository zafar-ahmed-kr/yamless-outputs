resource "azurerm_cosmosdb_account" "this" {
  name                          = "cosmos-${var.app_name}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  offer_type                    = "Standard"
  kind                          = "MongoDB"
  mongo_server_version          = var.server_version
  automatic_failover_enabled    = false
  public_network_access_enabled = false

  consistency_policy {
    consistency_level = var.consistency_level
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableMongo"
  }

  dynamic "capabilities" {
    for_each = var.throughput_mode == "serverless" ? [1] : []
    content {
      name = "EnableServerless"
    }
  }

  backup {
    type                = "Periodic"
    interval_in_minutes = 240
    retention_in_hours  = 8
  }

  tags = var.tags
}

resource "azurerm_key_vault_secret" "mongo_url" {
  name            = "mongodb-url"
  value           = azurerm_cosmosdb_account.this.connection_strings[0]
  key_vault_id    = var.keyvault_id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h")

  depends_on = [var.keyvault_rbac_ready]

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
