resource "azurerm_servicebus_namespace" "this" {
  name                         = "sb-${var.app_name}-${var.environment}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = var.sb_sku
  minimum_tls_version          = "1.2"
  local_auth_enabled           = false
  public_network_access_enabled = false
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_servicebus_queue" "main" {
  name         = var.queue_name
  namespace_id = azurerm_servicebus_namespace.this.id

  max_delivery_count                   = var.max_delivery_count
  dead_lettering_on_message_expiration = true
  default_message_ttl                  = "P${var.message_ttl_days}D"
}

# Least-privilege: receiver role only (not sender/manage)
resource "azurerm_role_assignment" "sb_receiver" {
  scope                = azurerm_servicebus_namespace.this.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = var.managed_identity_principal_id
}

resource "azurerm_key_vault_secret" "sb_connection" {
  name            = "servicebus-connection-string"
  value           = azurerm_servicebus_namespace.this.default_primary_connection_string
  key_vault_id    = var.keyvault_id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h")

  depends_on = [var.keyvault_rbac_ready]

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
