variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "log_name" { type = string }
variable "env_name" { type = string }
variable "web_app_name" { type = string }
variable "worker_job_name" { type = string }

variable "use_acr_images" { type = bool }
variable "acr_login_server" { type = string }
variable "web_image" { type = string }
variable "worker_image" { type = string }

variable "web_identity_id" { type = string }
variable "worker_identity_id" { type = string }
variable "web_identity_client_id" { type = string }
variable "worker_identity_client_id" { type = string }

variable "storage_account_name" { type = string }
variable "storage_connection_string" {
  type      = string
  sensitive = true
}
variable "queue_name" { type = string }

variable "search_endpoint" { type = string }
variable "search_index_name" { type = string }
variable "openai_endpoint" { type = string }
variable "embedding_deployment" { type = string }
variable "chat_deployment" { type = string }

variable "web_cpu" { type = number }
variable "web_memory" { type = string }
variable "worker_cpu" { type = number }
variable "worker_memory" { type = string }

variable "tags" { type = map(string) }
