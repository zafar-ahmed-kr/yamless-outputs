variable "app_name"                    { type = string }
variable "environment"                 { type = string }
variable "resource_group_name"         { type = string }
variable "tags"                        { type = map(string) }
variable "container_app_environment_id" { type = string }
variable "managed_identity_id"         { type = string }
variable "managed_identity_client_id"  { type = string }
variable "image"                       { type = string }
variable "target_port"                 { type = number; default = 8080 }
variable "ingress_external"            { type = bool; default = null }
variable "min_replicas"                { type = number; default = 1 }
variable "max_replicas"                { type = number; default = 10 }
variable "scale_trigger"               { type = string; default = "http" }
variable "keyvault_uri"                { type = string }
variable "keyvault_secret_names"       { type = list(string); default = [] }
variable "servicebus_namespace"        { type = string; default = "" }
