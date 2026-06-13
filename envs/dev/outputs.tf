output "resource_group_name" {
  value = module.resource_group.name
}

output "storage_account_name" {
  value = module.storage.name
}

output "acr_name" {
  value = module.acr.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "search_service_name" {
  value = module.search.name
}

output "search_endpoint" {
  value = module.search.endpoint
}

output "search_index_name" {
  value = var.search_index_name
}

output "openai_endpoint" {
  value = module.openai.endpoint
}

output "web_app_name" {
  value = module.container_apps.web_app_name
}

output "web_app_fqdn" {
  value = module.container_apps.web_app_fqdn
}

output "worker_job_name" {
  value = module.container_apps.worker_job_name
}

output "index_queue_name" {
  value = module.storage.index_queue_name
}
