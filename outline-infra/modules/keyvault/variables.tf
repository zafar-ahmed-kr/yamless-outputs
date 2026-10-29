variable "app_name"                    { type = string }
variable "environment"                 { type = string }
variable "location"                    { type = string }
variable "resource_group_name"         { type = string }
variable "tags"                        { type = map(string) }
variable "managed_identity_principal_id" { type = string }
