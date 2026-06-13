resource "azurerm_cognitive_account" "openai" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  kind     = "OpenAI"
  sku_name = "S0"

  custom_subdomain_name         = var.name
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.embedding_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.embedding_model_name
    version = var.embedding_model_version
  }

  sku {
    name     = var.embedding_sku_name
    capacity = var.embedding_capacity
  }
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.chat_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.chat_model_name
    version = var.chat_model_version
  }

  sku {
    name     = var.chat_sku_name
    capacity = var.chat_capacity
  }
}
