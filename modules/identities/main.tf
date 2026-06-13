resource "azurerm_user_assigned_identity" "web" {
  name                = var.web_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "worker" {
  name                = var.worker_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
