locals {
  required_acknowledgement = "I_UNDERSTAND_THIS_MAY_COST_MONEY"
  provision_cloud          = var.enable_cloud_resources && var.billing_acknowledgement == local.required_acknowledgement
  common_labels = {
    project    = "multicloud-devops-lab"
    managed_by = "terraform"
    cost_mode  = "explicit-opt-in"
  }
}

check "billing_guardrail" {
  assert {
    condition     = !var.enable_cloud_resources || var.billing_acknowledgement == local.required_acknowledgement
    error_message = "Cloud provisioning is blocked. Keep enable_cloud_resources=false, or explicitly set the required billing acknowledgement after reviewing pricing."
  }
}

resource "google_artifact_registry_repository" "app" {
  count = local.provision_cloud ? 1 : 0

  location      = var.gcp_region
  repository_id = "multicloud-devops-app"
  description   = "Docker images for ${var.project_name}"
  format        = "DOCKER"
  labels        = local.common_labels
}

resource "google_storage_bucket" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  name                        = var.artifact_bucket_name
  location                    = var.gcp_region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = local.common_labels

  versioning {
    enabled = true
  }
}
