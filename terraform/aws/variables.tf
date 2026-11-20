variable "aws_region" {
  description = "AWS region used only if real provisioning is explicitly enabled."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project prefix used in resource names and tags."
  type        = string
  default     = "multicloud-devops-lab"
}

variable "artifact_bucket_name" {
  description = "Globally unique S3 bucket name required only for real provisioning."
  type        = string
  default     = "replace-me-multicloud-devops-artifacts"
}

variable "enable_cloud_resources" {
  description = "Master switch. False means Terraform creates no AWS resources."
  type        = bool
  default     = false
}

variable "billing_acknowledgement" {
  description = "Second safety switch required before any potentially billable resources are planned."
  type        = string
  default     = ""
}
