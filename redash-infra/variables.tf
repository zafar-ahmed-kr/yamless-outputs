variable "app_name" {
  type        = string
  default     = "redash"
  description = "Application name — used as a prefix for all resource names."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment (dev, staging, prod)."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Azure region for all resources."
}

variable "image" {
  type        = string
  description = "Container image to deploy, e.g. myacr.azurecr.io/redash:latest"
}