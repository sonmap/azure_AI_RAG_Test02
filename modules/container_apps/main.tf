resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku               = "PerGB2018"
  retention_in_days = 30


  tags = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = var.env_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }


  tags = var.tags
}

resource "azurerm_container_app" "web" {
  name                         = var.web_app_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.web_identity_id]
  }

  dynamic "registry" {
    for_each = var.use_acr_images ? [1] : []
    content {
      server   = var.acr_login_server
      identity = var.web_identity_id
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 0
    max_replicas = 3

    container {
      name   = "web"
      image  = var.web_image
      cpu    = var.web_cpu
      memory = var.web_memory

      env {
        name  = "APP_MODE"
        value = "web"
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.web_identity_client_id
      }

      env {
        name  = "AZURE_STORAGE_ACCOUNT"
        value = var.storage_account_name
      }

      env {
        name  = "AZURE_QUEUE_NAME"
        value = var.queue_name
      }

      env {
        name  = "AZURE_SEARCH_ENDPOINT"
        value = var.search_endpoint
      }

      env {
        name  = "AZURE_SEARCH_INDEX"
        value = var.search_index_name
      }

      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }

      env {
        name  = "AZURE_OPENAI_EMBEDDING_DEPLOYMENT"
        value = var.embedding_deployment
      }

      env {
        name  = "AZURE_OPENAI_CHAT_DEPLOYMENT"
        value = var.chat_deployment
      }


      liveness_probe {
        transport = "HTTP"
        port      = 8000
        path      = "/healthz"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8000
        path      = "/healthz"
      }
    }
  }


  tags = var.tags
}

resource "azurerm_container_app_job" "worker" {
  name                         = var.worker_job_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id

  replica_timeout_in_seconds = 3600
  replica_retry_limit        = 3
  workload_profile_name      = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.worker_identity_id]
  }

  dynamic "registry" {
    for_each = var.use_acr_images ? [1] : []
    content {
      server   = var.acr_login_server
      identity = var.worker_identity_id
    }
  }

  secret {
    name  = "storage-connection-string"
    value = var.storage_connection_string
  }

  event_trigger_config {
    parallelism              = 1
    replica_completion_count = 1

    scale {
      min_executions              = 0
      max_executions              = 5
      polling_interval_in_seconds = 30

      rules {
        name             = "azure-queue-index-jobs"
        custom_rule_type = "azure-queue"

        metadata = {
          queueName   = var.queue_name
          queueLength = "1"
        }

        authentication {
          secret_name       = "storage-connection-string"
          trigger_parameter = "connection"
        }
      }
    }
  }

  template {
    container {
      name   = "indexer"
      image  = var.worker_image
      cpu    = var.worker_cpu
      memory = var.worker_memory

      env {
        name  = "APP_MODE"
        value = "worker"
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.worker_identity_client_id
      }

      env {
        name  = "AZURE_STORAGE_ACCOUNT"
        value = var.storage_account_name
      }

      env {
        name  = "AZURE_QUEUE_NAME"
        value = var.queue_name
      }

      env {
        name  = "AZURE_SEARCH_ENDPOINT"
        value = var.search_endpoint
      }

      env {
        name  = "AZURE_SEARCH_INDEX"
        value = var.search_index_name
      }

      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }

      env {
        name  = "AZURE_OPENAI_EMBEDDING_DEPLOYMENT"
        value = var.embedding_deployment
      }

      env {
        name  = "AZURE_OPENAI_CHAT_DEPLOYMENT"
        value = var.chat_deployment
      }
    }
  }


  tags = var.tags
}
