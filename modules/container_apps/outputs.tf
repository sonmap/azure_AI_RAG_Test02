output "environment_id" { value = azurerm_container_app_environment.this.id }
output "web_app_name" { value = azurerm_container_app.web.name }
output "web_app_fqdn" { value = azurerm_container_app.web.latest_revision_fqdn }
output "worker_job_name" { value = azurerm_container_app_job.worker.name }
