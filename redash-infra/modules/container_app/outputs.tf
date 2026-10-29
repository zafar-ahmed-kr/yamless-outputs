output "fqdn" {
  value = var.ingress_external != null ? azurerm_container_app.this.latest_revision_fqdn : null
}
output "name" { value = azurerm_container_app.this.name }
