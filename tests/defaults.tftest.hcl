# Mocked provider, so this runs with no AWS account and no credentials.
# These assertions pin the defaults that make the module worth using. If one
# fails, someone has quietly weakened the baseline.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  # KMS and S3 parse these at plan time, so the mock has to be real JSON.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-west-1" }
  }
}

variables {
  name = "example"
}

run "audit_key_rotates_and_resists_deletion" {
  command = plan

  assert {
    condition     = aws_kms_key.logs[0].enable_key_rotation == true
    error_message = "The audit log key must rotate."
  }

  assert {
    condition     = aws_kms_key.logs[0].deletion_window_in_days == 30
    error_message = "Losing this key makes every log unreadable. Keep the longest deletion window."
  }
}

run "cloudtrail_is_multi_region_and_validated" {
  command = plan

  assert {
    condition     = aws_cloudtrail.this[0].is_multi_region_trail == true
    error_message = "A single region trail misses activity in every other region."
  }

  assert {
    condition     = aws_cloudtrail.this[0].enable_log_file_validation == true
    error_message = "Without log file validation you cannot prove the trail was not edited."
  }

  assert {
    condition     = aws_s3_bucket_versioning.cloudtrail[0].versioning_configuration[0].status == "Enabled"
    error_message = "The trail bucket must be versioned."
  }
}

run "account_guardrails_are_on" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_account_public_access_block.this[0].block_public_acls,
      aws_s3_account_public_access_block.this[0].block_public_policy,
      aws_s3_account_public_access_block.this[0].ignore_public_acls,
      aws_s3_account_public_access_block.this[0].restrict_public_buckets,
    ])
    error_message = "All four S3 public access blocks must be set."
  }

  assert {
    condition     = aws_ebs_encryption_by_default.this[0].enabled == true
    error_message = "EBS encryption by default must be on."
  }

  assert {
    condition     = aws_ec2_instance_metadata_defaults.this[0].http_tokens == "required"
    error_message = "IMDSv2 must be the regional default."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].minimum_password_length >= 14
    error_message = "CIS requires at least 14 characters."
  }
}

run "security_hub_uses_the_current_cis_benchmark" {
  command = plan

  assert {
    condition     = endswith(local.standard_arns["cis-aws-foundations-benchmark"], "/v/5.0.0")
    error_message = "CIS v5.0.0 is the current benchmark. Check describe-standards before changing this."
  }

  assert {
    condition     = contains(var.securityhub_standards, "cis-aws-foundations-benchmark")
    error_message = "CIS should be subscribed by default."
  }
}

run "github_oidc_subjects_must_be_pinned" {
  command = plan

  variables {
    github_oidc_roles = {
      "wildcard" = { subjects = ["repo:*"] }
    }
  }

  expect_failures = [var.github_oidc_roles]
}
