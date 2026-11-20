variable "location" {
  description = "Azure region used only if real provisioning is explicitly enabled."
  type        = string
  default     = "Central India"
}

variable "project_name" {
  description = "Project prefix used in resource names and tags."
  type        = string
  default     = "multicloud-devops-lab"
}

variable "resource_group_name" {
  description = "Azure resource group name."
  type        = string
  default     = "rg-multicloud-devops-lab"
}

variable "container_registry_name" {
  description = "Globally unique, alphanumeric Azure Container Registry name."
  type        = string
  default     = "replacememulticloudacr"
}

variable "storage_account_name" {
  description = "Globally unique, lowercase alphanumeric Azure Storage account name."
  type        = string
  default     = "replacememcstorage"
}

variable "enable_cloud_resources" {
  description = "Master switch. False means Terraform creates no Azure resources."
  type        = bool
  default     = false
}

variable "billing_acknowledgement" {
  description = "Second safety switch required before any potentially billable resources are planned."
  type        = string
  default     = ""
}
