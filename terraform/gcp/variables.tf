variable "gcp_project_id" {
  description = "GCP project ID used only if real provisioning is explicitly enabled."
  type        = string
  default     = "replace-me-project-id"
}

variable "gcp_region" {
  description = "GCP region used for the Artifact Registry repository."
  type        = string
  default     = "asia-south1"
}

variable "project_name" {
  description = "Project prefix used in labels and descriptions."
  type        = string
  default     = "multicloud-devops-lab"
}

variable "artifact_bucket_name" {
  description = "Globally unique Cloud Storage bucket name required only for real provisioning."
  type        = string
  default     = "replace-me-multicloud-devops-artifacts"
}

variable "enable_cloud_resources" {
  description = "Master switch. False means Terraform creates no GCP resources."
  type        = bool
  default     = false
}

variable "billing_acknowledgement" {
  description = "Second safety switch required before any potentially billable resources are planned."
  type        = string
  default     = ""
}
