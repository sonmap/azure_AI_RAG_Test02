resource "azurerm_role_assignment" "web_blob" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.web_principal_id
}

resource "azurerm_role_assignment" "worker_blob" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.worker_principal_id
}

resource "azurerm_role_assignment" "web_queue" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = var.web_principal_id
}

resource "azurerm_role_assignment" "worker_queue" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = var.worker_principal_id
}

resource "azurerm_role_assignment" "web_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.web_principal_id
}

resource "azurerm_role_assignment" "worker_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.worker_principal_id
}

resource "azurerm_role_assignment" "web_search_reader" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Reader"
  principal_id         = var.web_principal_id
}

resource "azurerm_role_assignment" "worker_search_contributor" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = var.worker_principal_id
}

resource "azurerm_role_assignment" "web_keyvault_secrets" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.web_principal_id
}

resource "azurerm_role_assignment" "worker_keyvault_secrets" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.worker_principal_id
}

resource "azurerm_role_assignment" "web_openai_user" {
  scope                = var.openai_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = var.web_principal_id
}

resource "azurerm_role_assignment" "worker_openai_user" {
  scope                = var.openai_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = var.worker_principal_id
}
