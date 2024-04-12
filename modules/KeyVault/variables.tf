variable "key_vault_name" {
  type = string
  description = "The name of the key vault"
}

variable "location" {
  type = string
  description = "The location for the key vault"
}

variable "rg_name" {
  type = string
  description = "The name of the resource group"
}

variable "tenant_id" {
  type = string
  description = "The tenant ID"
}

variable "object_id" {
  type = string
  description = "The object ID"
}
