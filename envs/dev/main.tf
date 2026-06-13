terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result

  rg_name = "rg-${var.project}-${var.env}-${var.location_cd}"

  tags = merge(var.extra_tags, {
    project = var.project
    env     = var.env
    owner   = var.owner
    system  = "ppt-document-llm"
  })
}

module "resource_group" {
  source   = "../../modules/resource_group"
  name     = local.rg_name
  location = var.location
  tags     = local.tags
}

module "storage" {
  source              = "../../modules/storage"
  resource_group_name = module.resource_group.name
  location            = var.location
  name                = "st${var.project}${var.env}${local.suffix}"
  tags                = local.tags
}

module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = module.resource_group.name
  location            = var.location
  name                = "kv-${var.project}-${var.env}-${local.suffix}"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags
}

module "search" {
  source              = "../../modules/search"
  resource_group_name = module.resource_group.name
  location            = var.location
  name                = "srch-${var.project}-${var.env}-${var.location_cd}"

  sku                           = var.search_sku
  semantic_search_sku           = var.semantic_search_sku
  replica_count                 = var.search_replica_count
  partition_count               = var.search_partition_count
  public_network_access_enabled = var.search_public_network_access_enabled

  tags = local.tags
}

module "openai" {
  source              = "../../modules/openai"
  resource_group_name = module.resource_group.name
  location            = var.openai_location
  name                = "aoai-${var.project}-${var.env}-${var.location_cd}-${local.suffix}"

  embedding_deployment_name = var.embedding_deployment_name
  embedding_model_name      = var.embedding_model_name
  embedding_model_version   = var.embedding_model_version
  embedding_capacity        = var.embedding_capacity
  embedding_sku_name        = var.embedding_sku_name

  chat_deployment_name = var.chat_deployment_name
  chat_model_name      = var.chat_model_name
  chat_model_version   = var.chat_model_version
  chat_capacity        = var.chat_capacity
  chat_sku_name        = var.chat_sku_name

  tags = local.tags
}

module "acr" {
  source              = "../../modules/acr"
  resource_group_name = module.resource_group.name
  location            = var.location
  name                = "acr${var.project}${var.env}${local.suffix}"
  tags                = local.tags
}

module "identities" {
  source              = "../../modules/identities"
  resource_group_name = module.resource_group.name
  location            = var.location

  web_identity_name    = "id-${var.project}-web-${var.env}"
  worker_identity_name = "id-${var.project}-worker-${var.env}"

  tags = local.tags
}

module "rbac" {
  source = "../../modules/rbac"

  storage_account_id = module.storage.id
  acr_id             = module.acr.id
  search_service_id  = module.search.id
  keyvault_id        = module.keyvault.id
  openai_id          = module.openai.id

  web_principal_id    = module.identities.web_principal_id
  worker_principal_id = module.identities.worker_principal_id
}

module "container_apps" {
  source              = "../../modules/container_apps"
  resource_group_name = module.resource_group.name
  location            = var.location

  log_name = "log-${var.project}-${var.env}-${var.location_cd}"
  env_name = "cae-${var.project}-${var.env}-${var.location_cd}"

  web_app_name    = "ca-${var.project}-web-${var.env}"
  worker_job_name = "caj-${var.project}-indexer-${var.env}"

  use_acr_images   = var.use_acr_images
  acr_login_server = module.acr.login_server
  web_image        = var.web_image
  worker_image     = var.worker_image

  web_identity_id           = module.identities.web_identity_id
  worker_identity_id        = module.identities.worker_identity_id
  web_identity_client_id    = module.identities.web_client_id
  worker_identity_client_id = module.identities.worker_client_id

  storage_account_name      = module.storage.name
  storage_connection_string = module.storage.primary_connection_string
  queue_name                = module.storage.index_queue_name

  search_endpoint   = module.search.endpoint
  search_index_name = var.search_index_name

  openai_endpoint      = module.openai.endpoint
  embedding_deployment = var.embedding_deployment_name
  chat_deployment      = var.chat_deployment_name

  web_cpu       = var.web_cpu
  web_memory    = var.web_memory
  worker_cpu    = var.worker_cpu
  worker_memory = var.worker_memory

  tags = local.tags

  depends_on = [module.rbac]
}
