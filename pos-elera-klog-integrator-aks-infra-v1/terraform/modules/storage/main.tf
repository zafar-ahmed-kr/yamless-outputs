resource "azurerm_storage_account" "this" {
  name                     = substr(lower(replace(replace("st${var.app_name}${var.environment}", "-", ""), ".", "")), 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  # Golden standard: no public blob access
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false

  blob_properties {
    delete_retention_policy {
      days = var.delete_retention_days
    }
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  sas_policy {
    expiration_period = "01.00:00:00" # 1 day max SAS lifetime
    expiration_action = "Log"
  }
}

resource "azurerm_storage_container" "main" {
  name                  = var.app_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# Least-privilege: contributor on blob data only, not the account itself
resource "azurerm_role_assignment" "blob_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.managed_identity_principal_id
}

resource "azurerm_key_vault_secret" "storage_connection" {
  name            = "storage-connection-string"
  value           = azurerm_storage_account.this.primary_connection_string
  key_vault_id    = var.keyvault_id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h")

  depends_on = [var.keyvault_rbac_ready]

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
