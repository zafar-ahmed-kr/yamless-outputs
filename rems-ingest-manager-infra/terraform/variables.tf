variable "app_name" {
  type        = string
  default     = "pos-service-instore-rems-ingest-manager"
}

variable "environment" {
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "image" {
  type        = string
  description = "Container image to deploy, e.g. <acr>.azurecr.io/pos-service-instore-rems-ingest-manager:latest"
}

variable "namespace" {
  type        = string
  default     = "pos-service-instore-rems-ingest-manager"
  description = "Kubernetes namespace for the workload."
}