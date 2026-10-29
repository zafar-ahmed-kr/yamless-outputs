resource "azurerm_container_registry" "this" {
  name                = "acr${replace(var.app_name, "-", "")}${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = var.tags

  retention_policy {
    days    = 30
    enabled = true
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  name                      = "aks-${var.app_name}-${var.environment}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = "${var.app_name}-${var.environment}"
  tags                      = var.tags
  local_account_disabled    = true
  automatic_channel_upgrade = "patch"
  azure_policy_enabled      = true

  default_node_pool {
    name                        = "system"
    node_count                  = 2
    vm_size                     = "Standard_D2s_v3"
    vnet_subnet_id              = var.aks_subnet_id
    os_disk_size_gb             = 30
    os_disk_type                = "Ephemeral"
    max_pods                    = 50
    type                        = "VirtualMachineScaleSets"
    only_critical_addons_enabled = true

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Required for Workload Identity and Key Vault CSI
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # KEDA for queue-based autoscaling
  workload_autoscaler_profile {
    keda_enabled = true
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}

# Allow the cluster to pull images from ACR
resource "azurerm_role_assignment" "acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.this.id
  skip_service_principal_aad_check = true
}
