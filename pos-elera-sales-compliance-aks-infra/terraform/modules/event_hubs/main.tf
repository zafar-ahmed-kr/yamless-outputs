resource "azurerm_eventhub_namespace" "this" {
  name                          = "ehns-${var.app_name}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.eh_sku
  capacity                      = var.capacity
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  local_authentication_enabled  = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_eventhub" "this" {
  name              = var.app_name
  namespace_id      = azurerm_eventhub_namespace.this.id
  partition_count   = var.partition_count
  message_retention = var.message_retention
}

resource "azurerm_eventhub_consumer_group" "this" {
  name                = "${var.app_name}-cg"
  namespace_name      = azurerm_eventhub_namespace.this.name
  eventhub_name       = azurerm_eventhub.this.name
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "eh_receiver" {
  scope                = azurerm_eventhub_namespace.this.id
  role_definition_name = "Azure Event Hubs Data Receiver"
  principal_id         = var.managed_identity_principal_id
}

resource "azurerm_key_vault_secret" "eventhubs_connection_string" {
  name            = "eventhubs-connection-string"
  value           = azurerm_eventhub_namespace.this.default_primary_connection_string
  key_vault_id    = var.keyvault_id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h")

  depends_on = [var.keyvault_rbac_ready]

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
