resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  sku_name                    = "standard"
  enabled_for_disk_encryption = false
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
  rbac_authorization_enabled  = true
  #enable_rbac_authorization   = true
  public_network_access_enabled = true

  tags = var.tags
}
