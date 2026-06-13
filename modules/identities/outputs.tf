output "web_identity_id" { value = azurerm_user_assigned_identity.web.id }
output "web_principal_id" { value = azurerm_user_assigned_identity.web.principal_id }
output "web_client_id" { value = azurerm_user_assigned_identity.web.client_id }

output "worker_identity_id" { value = azurerm_user_assigned_identity.worker.id }
output "worker_principal_id" { value = azurerm_user_assigned_identity.worker.principal_id }
output "worker_client_id" { value = azurerm_user_assigned_identity.worker.client_id }
