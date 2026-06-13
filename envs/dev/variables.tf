variable "project" {
  type    = string
  default = "docsearch"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "sonmap"
}

variable "location" {
  type    = string
  default = "koreacentral"
}

variable "location_cd" {
  type    = string
  default = "krc"
}

variable "openai_location" {
  type    = string
  default = "koreacentral"
}

variable "search_sku" {
  type    = string
  default = "basic"
}

variable "semantic_search_sku" {
  type    = string
  default = "free"
}

variable "search_replica_count" {
  type    = number
  default = 1
}

variable "search_partition_count" {
  type    = number
  default = 1
}

variable "search_public_network_access_enabled" {
  type    = bool
  default = true
}

variable "search_index_name" {
  type    = string
  default = "ppt-doc-chunks"
}

variable "create_search_index" {
  type    = bool
  default = true
}

variable "embedding_dimensions" {
  type    = number
  default = 1536
}

variable "embedding_deployment_name" {
  type    = string
  default = "text-embedding-3-small"
}

variable "embedding_model_name" {
  type    = string
  default = "text-embedding-3-small"
}

variable "embedding_model_version" {
  type    = string
  default = "1"
}

variable "embedding_capacity" {
  type    = number
  default = 10
}

variable "chat_deployment_name" {
  type    = string
  default = "gpt-4o-mini"
}

variable "chat_model_name" {
  type    = string
  default = "gpt-4o-mini"
}

variable "chat_model_version" {
  type    = string
  default = "2024-07-18"
}

variable "chat_capacity" {
  type    = number
  default = 10
}

variable "use_acr_images" {
  type    = bool
  default = false
}

variable "web_image" {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "worker_image" {
  type    = string
  default = "mcr.microsoft.com/k8se/quickstart-jobs:latest"
}

variable "web_cpu" {
  type    = number
  default = 0.5
}

variable "web_memory" {
  type    = string
  default = "1Gi"
}

variable "worker_cpu" {
  type    = number
  default = 1.0
}

variable "worker_memory" {
  type    = string
  default = "2Gi"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "embedding_sku_name" {
  type    = string
  default = "GlobalStandard"
}

variable "chat_sku_name" {
  type    = string
  default = "GlobalStandard"
}
