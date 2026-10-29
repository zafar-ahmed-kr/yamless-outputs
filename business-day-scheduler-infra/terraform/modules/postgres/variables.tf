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
