variable "app_name"           { type = string }
variable "environment"        { type = string }
variable "location"           { type = string }
variable "resource_group_name" { type = string }
variable "tags"               { type = map(string) }
variable "keyvault_id"        { type = string }
variable "keyvault_rbac_ready" {
  type    = any
  default = null
  description = "Dependency token — pass the KV secrets officer role assignment to ensure RBAC is ready before writing secrets."
}
variable "pg_version"            { type = string; default = "16" }
variable "sku_name"              { type = string; default = "B_Standard_B1ms" }
variable "storage_mb"            { type = number; default = 32768 }
variable "backup_retention_days" { type = number; default = 7 }
variable "geo_redundant_backup"  { type = bool;   default = false }
