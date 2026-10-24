# All operations are mock plans. Policies are produced by the real jsonencode
# expressions, with only provider-computed identities supplied below.
mock_provider "aws" {
  override_during = plan
}

override_resource {
  target          = aws_s3_bucket.state
  override_during = plan
  values = {
    id  = "cloudkube-test-state-123456789012"
    arn = "arn:aws:s3:::cloudkube-test-state-123456789012"
  }
}

override_resource {
  target          = aws_kms_key.state
  override_during = plan
  values = {
    id  = "11111111-2222-3333-4444-555555555555"
    arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  }
}

variables {
  aws_account_id            = "123456789012"
  aws_region                = "us-east-1"
  state_bucket_name         = "cloudkube-test-state-123456789012"
  workload_state_key        = "cloudkube/production/terraform.tfstate"
  github_subject_format     = "legacy"
  github_oidc_provider_mode = "create"
}

run "protected_state_storage" {
  command = plan

  assert {
    condition = (
      aws_s3_bucket.state.bucket == var.state_bucket_name &&
      !aws_s3_bucket.state.force_destroy &&
      aws_s3_bucket_versioning.state.bucket == aws_s3_bucket.state.id &&
      aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled" &&
      aws_s3_bucket_ownership_controls.state.rule[0].object_ownership == "BucketOwnerEnforced" &&
      aws_s3_bucket_public_access_block.state.block_public_acls &&
      aws_s3_bucket_public_access_block.state.block_public_policy &&
      aws_s3_bucket_public_access_block.state.ignore_public_acls &&
      aws_s3_bucket_public_access_block.state.restrict_public_buckets
    )
    error_message = "State storage must retain versions, disable ACLs, block public access and refuse force-destroy."
  }

  assert {
    condition = (
      aws_kms_key.state.key_usage == "ENCRYPT_DECRYPT" &&
      aws_kms_key.state.customer_master_key_spec == "SYMMETRIC_DEFAULT" &&
      aws_kms_key.state.enable_key_rotation &&
      aws_kms_key.state.deletion_window_in_days == 30 &&
      one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" &&
      one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == aws_kms_key.state.arn &&
      !one(aws_s3_bucket_server_side_encryption_configuration.state.rule).bucket_key_enabled
    )
    error_message = "Both state and lockfiles must use the rotating symmetric key, without S3 Bucket Keys changing the IAM encryption context."
  }

  assert {
    condition = (
      length(jsondecode(aws_kms_key.state.policy).Statement) == 1 &&
      jsondecode(aws_kms_key.state.policy).Statement[0].Effect == "Allow" &&
      jsondecode(aws_kms_key.state.policy).Statement[0].Principal.AWS == "arn:aws:iam::123456789012:root" &&
      jsondecode(aws_kms_key.state.policy).Statement[0].Action == "kms:*" &&
      jsondecode(aws_kms_key.state.policy).Statement[0].Resource == "*"
    )
    error_message = "The key policy must delegate only to the intended account, leaving individual role grants to IAM."
  }
}

run "transport_and_encryption_headers_are_enforced" {
  command = plan

  assert {
    condition = (
      length(jsondecode(aws_s3_bucket_policy.state.policy).Statement) == 3 &&
      alltrue([for statement in jsondecode(aws_s3_bucket_policy.state.policy).Statement : statement.Effect == "Deny" && statement.Principal == "*"]) &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Action == "s3:*" &&
      toset(jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Resource) == toset([aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]) &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false" &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Condition.Bool["aws:PrincipalIsAWSService"] == "false"
    )
    error_message = "The bucket policy must deny insecure client transport for both bucket and object operations."
  }

  assert {
    condition = (
      alltrue([
        for index in [1, 2] :
        jsondecode(aws_s3_bucket_policy.state.policy).Statement[index].Action == "s3:PutObject" &&
        jsondecode(aws_s3_bucket_policy.state.policy).Statement[index].Resource == "${aws_s3_bucket.state.arn}/*"
      ]) &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[1].Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "aws:kms" &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[2].Condition.StringNotEquals["s3:x-amz-server-side-encryption-aws-kms-key-id"] == aws_kms_key.state.arn
    )
    error_message = "Uploads must explicitly request SSE-KMS and the exact state key, including lockfiles and manual recovery uploads."
  }
}

run "backend_outputs_have_separate_keys_and_no_credentials" {
  command = plan

  assert {
    condition = (
      toset(keys(output.backend_config)) == toset(["workload", "bootstrap"]) &&
      output.backend_config.workload.key == var.workload_state_key &&
      output.backend_config.bootstrap.key == "bootstrap/terraform.tfstate" &&
      alltrue([
        for config in values(output.backend_config) :
        toset(keys(config)) == toset(["bucket", "key", "region", "encrypt", "use_lockfile", "kms_key_id", "allowed_account_ids"]) &&
        config.bucket == aws_s3_bucket.state.id && config.region == var.aws_region &&
        config.encrypt && config.use_lockfile && config.kms_key_id == aws_kms_key.state.arn &&
        config.allowed_account_ids == [var.aws_account_id]
      ])
    )
    error_message = "Backend output must separate operator/bootstrap and workload keys, expose only destination parameters, and require encryption, native locking and the intended account."
  }
}

run "custom_operator_key_is_preserved" {
  command = plan

  variables {
    bootstrap_state_key = "operators/cloudkube/bootstrap.tfstate"
  }

  assert {
    condition     = output.backend_config.bootstrap.key == "operators/cloudkube/bootstrap.tfstate"
    error_message = "An explicit operator-only bootstrap state key must reach the migration output."
  }
}

run "reject_invalid_account" {
  command = plan

  variables {
    aws_account_id = "12345"
  }

  expect_failures = [var.aws_account_id]
}

run "reject_unsupported_partition" {
  command = plan

  variables {
    aws_region = "cn-north-1"
  }

  expect_failures = [var.aws_region]
}

run "reject_invalid_bucket_name" {
  command = plan

  variables {
    state_bucket_name = "CloudKube-invalid"
  }

  expect_failures = [var.state_bucket_name]
}

run "reject_shared_state_key" {
  command = plan

  variables {
    workload_state_key = "bootstrap/terraform.tfstate"
  }

  expect_failures = [var.workload_state_key]
}

run "reject_workload_over_bootstrap_lock" {
  command = plan

  variables {
    workload_state_key = "bootstrap/terraform.tfstate.tflock"
  }

  expect_failures = [var.workload_state_key]
}

run "reject_bootstrap_over_workload_lock" {
  command = plan

  variables {
    bootstrap_state_key = "cloudkube/production/terraform.tfstate.tflock"
  }

  expect_failures = [var.workload_state_key]
}

run "reject_wildcard_state_key" {
  command = plan

  variables {
    workload_state_key = "cloudkube/*/terraform.tfstate"
  }

  expect_failures = [var.workload_state_key]
}

run "reject_parent_directory_key" {
  command = plan

  variables {
    bootstrap_state_key = "../bootstrap.tfstate"
  }

  expect_failures = [var.bootstrap_state_key]
}
