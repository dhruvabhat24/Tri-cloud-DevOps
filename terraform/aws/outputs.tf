output "cloud_resources_enabled" {
  description = "True only when both cloud-provisioning safety switches are set."
  value       = local.provision_cloud
}

output "container_registry_url" {
  description = "ECR repository URL when real provisioning is enabled."
  value       = try(aws_ecr_repository.app[0].repository_url, null)
}

output "artifact_bucket" {
  description = "S3 artifact bucket name when real provisioning is enabled."
  value       = try(aws_s3_bucket.artifacts[0].bucket, null)
}
