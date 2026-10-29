resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${var.app_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
