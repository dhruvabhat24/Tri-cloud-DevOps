output "cloud_resources_enabled" {
  description = "True only when both cloud-provisioning safety switches are set."
  value       = local.provision_cloud
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository name when real provisioning is enabled."
  value       = try(google_artifact_registry_repository.app[0].name, null)
}

output "artifact_bucket" {
  description = "Cloud Storage artifact bucket name when real provisioning is enabled."
  value       = try(google_storage_bucket.artifacts[0].name, null)
}
