output "cloud_resources_enabled" {
  description = "True only when both cloud-provisioning safety switches are set."
  value       = local.provision_cloud
}

output "container_registry_login_server" {
  description = "ACR login server when real provisioning is enabled."
  value       = try(azurerm_container_registry.app[0].login_server, null)
}

output "artifact_storage_account" {
  description = "Storage account name when real provisioning is enabled."
  value       = try(azurerm_storage_account.artifacts[0].name, null)
}
