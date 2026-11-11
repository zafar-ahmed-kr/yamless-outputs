data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                       = substr(trimsuffix(trimprefix("kv-${var.app_name}-${var.environment}", "-"), "-"), 0, 24)
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  tags                       = var.tags

  # Disable legacy access policies in favour of RBAC
  enable_rbac_authorization    = true
  public_network_access_enabled = false

  # Deny public access; allow Azure trusted services (Container Apps, etc.)
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

# Grant the managed identity read access to secrets (least privilege)
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.managed_identity_principal_id
}

# Grant the deploying principal admin rights so it can write secrets during apply
resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
