output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = module.aks_cluster.cluster_name
}

output "acr_login_server" {
  value       = module.aks_cluster.acr_login_server
  description = "Push your image here before deploying."
}

output "keyvault_name" {
  value = module.keyvault.name
}

output "workload_identity_client_id" {
  description = "Set as AZURE_CLIENT_ID in local dev; annotated on the Kubernetes ServiceAccount."
  value       = module.aks_workload_identity.client_id
}


output "storage_account_name" {
  value = module.storage.account_name
}

output "servicebus_namespace" {
  value = module.servicebus.namespace_name
}
