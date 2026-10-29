resource "azurerm_container_app" "this" {
  name                         = "ca-${var.app_name}-${var.environment}"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  # Secrets sourced from Key Vault — never plaintext values in config
  dynamic "secret" {
    for_each = var.keyvault_secret_names
    content {
      name                = secret.value
      key_vault_secret_id = "${var.keyvault_uri}secrets/${secret.value}"
      identity            = var.managed_identity_id
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.app_name
      image  = var.image
      cpu    = 0.5
      memory = "1Gi"

      dynamic "env" {
        for_each = var.keyvault_secret_names
        content {
          name        = upper(env.value)
          secret_name = env.value
        }
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.managed_identity_client_id
      }
    }

    dynamic "http_scale_rule" {
      for_each = var.scale_trigger == "http" ? [1] : []
      content {
        name                = "http-scaler"
        concurrent_requests = "10"
      }
    }

    dynamic "custom_scale_rule" {
      for_each = var.scale_trigger == "queue" ? [1] : []
      content {
        name             = "queue-scaler"
        custom_rule_type = "azure-servicebus"
        metadata = {
          queueName  = var.app_name
          namespace  = var.servicebus_namespace
          messageCount = "10"
        }
        authentication {
          secret_name       = "azure-servicebus-connection-string"
          trigger_parameter = "connection"
        }
      }
    }
  }

  dynamic "ingress" {
    for_each = var.ingress_external != null ? [1] : []
    content {
      external_enabled = var.ingress_external
      target_port      = var.target_port
      transport        = "auto"

      traffic_weight {
        latest_revision = true
        percentage      = 100
      }
    }
  }
}
