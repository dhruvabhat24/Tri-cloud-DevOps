mock_provider "aws" {}

run "defaults_create_nothing" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository.app) == 0 && length(aws_s3_bucket.artifacts) == 0
    error_message = "The default configuration must create zero AWS resources."
  }
}

run "mocked_resources_are_valid" {
  command = plan

  variables {
    enable_cloud_resources   = true
    billing_acknowledgement  = "I_UNDERSTAND_THIS_MAY_COST_MONEY"
    artifact_bucket_name     = "mock-multicloud-devops-artifacts"
  }

  assert {
    condition     = length(aws_ecr_repository.app) == 1 && length(aws_s3_bucket.artifacts) == 1
    error_message = "The opted-in AWS design should include one registry and one artifact bucket."
  }
}

run "missing_acknowledgement_is_rejected" {
  command = plan

  variables {
    enable_cloud_resources = true
  }

  expect_failures = [check.billing_guardrail]
}
