variable "app_name"           { type = string }
variable "environment"        { type = string }
variable "location"           { type = string }
variable "resource_group_name" { type = string }
variable "tags"               { type = map(string) }
variable "namespace"          { type = string }
variable "oidc_issuer_url"    { type = string }
variable "keyvault_id"        { type = string }
