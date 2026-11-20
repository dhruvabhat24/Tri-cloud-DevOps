mock_provider "azurerm" {}

run "defaults_create_nothing" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group.project) == 0 && length(azurerm_container_registry.app) == 0
    error_message = "The default configuration must create zero Azure resources."
  }
}

run "mocked_resources_are_valid" {
  command = plan

  variables {
    enable_cloud_resources  = true
    billing_acknowledgement = "I_UNDERSTAND_THIS_MAY_COST_MONEY"
  }

  assert {
    condition     = length(azurerm_container_registry.app) == 1 && length(azurerm_storage_account.artifacts) == 1
    error_message = "The opted-in Azure design should include one registry and one artifact store."
  }
}

run "missing_acknowledgement_is_rejected" {
  command = plan

  variables {
    enable_cloud_resources = true
  }

  expect_failures = [check.billing_guardrail]
}
