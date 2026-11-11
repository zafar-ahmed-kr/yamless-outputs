variable "app_name" {
  type        = string
  default     = "pos-elera-sales-compliance"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment (dev, staging, production)."
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging, or production."
  }
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "image" {
  type        = string
  description = "Container image to deploy, e.g. <acr>.azurecr.io/pos-elera-sales-compliance:latest"
}

variable "cost_center" {
  type        = string
  default     = ""
  description = "Cost center code for billing attribution (GR-COST-001). Required for production."
}

variable "team" {
  type        = string
  default     = ""
  description = "Owning team name (GR-COST-001). Required for production."
}

variable "owner" {
  type        = string
  default     = ""
  description = "Service owner contact (GR-COST-001). Required for production."
}

variable "runbook_url" {
  type        = string
  default     = ""
  description = "URL to the operational runbook (GR-OPS-005). Required for production."
}

variable "namespace" {
  type        = string
  default     = "pos-elera-sales-compliance"
  description = "Kubernetes namespace for the workload."
}