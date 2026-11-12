variable "app_name"                    { type = string }
variable "environment"                 { type = string }
variable "location"                    { type = string }
variable "resource_group_name"         { type = string }
variable "tags"                        { type = map(string) }
variable "queue_name"                  { type = string }
variable "managed_identity_principal_id" { type = string }
variable "keyvault_id"                 { type = string }
variable "keyvault_rbac_ready" {
  type    = any
  default = null
}
variable "sb_sku"             { type = string; default = "Standard" }
variable "max_delivery_count" { type = number; default = 10 }
variable "message_ttl_days"   { type = number; default = 14 }
