variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }

variable "embedding_deployment_name" { type = string }
variable "embedding_model_name" { type = string }
variable "embedding_model_version" { type = string }
variable "embedding_capacity" { type = number }

variable "chat_deployment_name" { type = string }
variable "chat_model_name" { type = string }
variable "chat_model_version" { type = string }
variable "chat_capacity" { type = number }

variable "tags" { type = map(string) }

variable "embedding_sku_name" {
  type    = string
  default = "GlobalStandard"
}

variable "chat_sku_name" {
  type    = string
  default = "GlobalStandard"
}
