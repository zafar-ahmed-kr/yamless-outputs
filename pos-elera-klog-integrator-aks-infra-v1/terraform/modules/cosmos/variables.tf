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
variable "consistency_level"  { type = string; default = "Session" }
variable "throughput_mode"    { type = string; default = "serverless" }
variable "max_autoscale_ru"   { type = number; default = null }
variable "server_version"     { type = string; default = "4.2" }
