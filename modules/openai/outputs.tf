output "id" { value = azurerm_cognitive_account.openai.id }
output "name" { value = azurerm_cognitive_account.openai.name }
output "endpoint" { value = azurerm_cognitive_account.openai.endpoint }
output "embedding_deployment_name" { value = azurerm_cognitive_deployment.embedding.name }
output "chat_deployment_name" { value = azurerm_cognitive_deployment.chat.name }
