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

resource "aws_ecr_repository" "app" {
  count = local.provision_cloud ? 1 : 0

  name                 = "${var.project_name}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  bucket        = var.artifact_bucket_name
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  bucket                  = aws_s3_bucket.artifacts[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count = local.provision_cloud ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
