locals {
  required_acknowledgement = "I_UNDERSTAND_THIS_MAY_COST_MONEY"
  provision_cloud          = var.enable_cloud_resources && var.billing_acknowledgement == local.required_acknowledgement
  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    CostMode  = "explicit-opt-in"
  }
}

check "billing_guardrail" {
  assert {
    condition     = !var.enable_cloud_resources || var.billing_acknowledgement == local.required_acknowledgement
    error_message = "Cloud provisioning is blocked. Keep enable_cloud_resources=false, or explicitly set the required billing acknowledgement after reviewing pricing."
  }
}

resource "azurerm_resource_group" "project" {
  count = local.provision_cloud ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "app" {
  count = local.provision_cloud ? 1 : 0

  name                          = var.container_registry_name
  resource_group_name           = azurerm_resource_group.project[0].name
  location                      = azurerm_resource_group.project[0].location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = local.common_tags
}

resource "azurerm_storage_account" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.project[0].name
  location                        = azurerm_resource_group.project[0].location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.common_tags
}

resource "azurerm_storage_container" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  name                  = "artifacts"
  storage_account_id    = azurerm_storage_account.artifacts[0].id
  container_access_type = "private"
}
