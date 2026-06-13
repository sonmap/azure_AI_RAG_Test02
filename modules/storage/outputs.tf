output "id" { value = azurerm_storage_account.this.id }
output "name" { value = azurerm_storage_account.this.name }
output "primary_connection_string" {
  value     = azurerm_storage_account.this.primary_connection_string
  sensitive = true
}
output "original_container_name" { value = azurerm_storage_container.original.name }
output "converted_pdf_container_name" { value = azurerm_storage_container.converted_pdf.name }
output "thumbnails_container_name" { value = azurerm_storage_container.thumbnails.name }
output "index_queue_name" { value = azurerm_storage_queue.index_jobs.name }
