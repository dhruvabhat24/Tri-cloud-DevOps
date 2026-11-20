mock_provider "google" {}

run "defaults_create_nothing" {
  command = plan

  assert {
    condition     = length(google_artifact_registry_repository.app) == 0 && length(google_storage_bucket.artifacts) == 0
    error_message = "The default configuration must create zero GCP resources."
  }
}

run "mocked_resources_are_valid" {
  command = plan

  variables {
    enable_cloud_resources  = true
    billing_acknowledgement = "I_UNDERSTAND_THIS_MAY_COST_MONEY"
    gcp_project_id          = "mock-project"
    artifact_bucket_name    = "mock-multicloud-devops-artifacts"
  }

  assert {
    condition     = length(google_artifact_registry_repository.app) == 1 && length(google_storage_bucket.artifacts) == 1
    error_message = "The opted-in GCP design should include one registry and one artifact bucket."
  }
}

run "missing_acknowledgement_is_rejected" {
  command = plan

  variables {
    enable_cloud_resources = true
  }

  expect_failures = [check.billing_guardrail]
}
