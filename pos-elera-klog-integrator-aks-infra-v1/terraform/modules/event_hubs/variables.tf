variable "app_name"                      { type = string }
variable "environment"                   { type = string }
variable "location"                      { type = string }
variable "resource_group_name"           { type = string }
variable "tags"                          { type = map(string) }
variable "managed_identity_principal_id" { type = string }
variable "keyvault_id"                   { type = string }
variable "keyvault_rbac_ready" {
  type    = any
  default = null
}
variable "eh_sku"            { type = string; default = "Standard" }
variable "capacity"          { type = number; default = 1 }
variable "partition_count"   { type = number; default = 2 }
variable "message_retention" { type = number; default = 1 }
