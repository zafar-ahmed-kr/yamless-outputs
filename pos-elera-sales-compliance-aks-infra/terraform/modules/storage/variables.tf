variable "app_name"                    { type = string }
variable "environment"                 { type = string }
variable "location"                    { type = string }
variable "resource_group_name"         { type = string }
variable "tags"                        { type = map(string) }
variable "managed_identity_principal_id" { type = string }
variable "keyvault_id"                 { type = string }
variable "keyvault_rbac_ready" {
  type    = any
  default = null
}
variable "account_replication_type" { type = string; default = "ZRS" }
variable "delete_retention_days"    { type = number; default = 7 }
