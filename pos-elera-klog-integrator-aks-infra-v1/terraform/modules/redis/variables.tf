variable "app_name"            { type = string }
variable "environment"         { type = string }
variable "location"            { type = string }
variable "resource_group_name" { type = string }
variable "tags"                { type = map(string) }
variable "keyvault_id"         { type = string }
variable "keyvault_rbac_ready" {
  type    = any
  default = null
}
variable "sku_name" { type = string; default = "Basic" }
variable "family"   { type = string; default = "C" }
variable "capacity" { type = number; default = 0 }
