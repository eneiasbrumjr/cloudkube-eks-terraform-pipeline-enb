# Mock identifiers and provider reads only. Trust and permission assertions decode
# the actual jsonencode documents from identity.tf, never a mocked policy document.
mock_provider "aws" {
  override_during = plan

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::cloudkube-test-state-123456789012"
      id  = "cloudkube-test-state-123456789012"
    }
  }
  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-4000-8000-000000000001"
      key_id = "00000000-0000-4000-8000-000000000001"
    }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }
  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      url            = "https://token.actions.githubusercontent.com"
      client_id_list = ["sts.amazonaws.com"]
    }
  }
}

variables {
  aws_account_id            = "123456789012"
  aws_region                = "us-east-1"
  name_prefix               = "cloudkube"
  state_bucket_name         = "cloudkube-test-state-123456789012"
  workload_state_key        = "workload/production/terraform.tfstate"
  github_oidc_provider_mode = "create"
  github_subject_format     = "legacy"
}

run "legacy_trust_and_backend_only_defaults" {
  command = plan

  assert {
    condition = jsondecode(aws_iam_role.github["plan"].assume_role_policy).Statement[0].Condition.StringEquals == {
      "token.actions.githubusercontent.com:aud"                 = "sts.amazonaws.com"
      "token.actions.githubusercontent.com:sub"                 = "repo:eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb:ref:refs/heads/main"
      "token.actions.githubusercontent.com:ref"                 = "refs/heads/main"
      "token.actions.githubusercontent.com:repository_id"       = "1016370567"
      "token.actions.githubusercontent.com:repository_owner_id" = "57417495"
    }
    error_message = "Plan trust must require the exact audience, branch subject, main ref and immutable repository IDs."
  }
  assert {
    condition = jsondecode(aws_iam_role.github["apply"].assume_role_policy).Statement[0].Condition.StringEquals == {
      "token.actions.githubusercontent.com:aud"                 = "sts.amazonaws.com"
      "token.actions.githubusercontent.com:sub"                 = "repo:eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb:environment:production"
      "token.actions.githubusercontent.com:ref"                 = "refs/heads/main"
      "token.actions.githubusercontent.com:repository_id"       = "1016370567"
      "token.actions.githubusercontent.com:repository_owner_id" = "57417495"
      "token.actions.githubusercontent.com:environment"         = "production"
    }
    error_message = "Apply trust must require production and main simultaneously, plus the exact repository identity."
  }
  assert {
    condition = alltrue([
      for role in ["plan", "apply"] :
      jsondecode(aws_iam_role.github[role].assume_role_policy).Statement[0].Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" &&
      jsondecode(aws_iam_role.github[role].assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity"
    ])
    error_message = "Only the selected account's GitHub provider may assume these roles through web identity."
  }
  assert {
    condition = (
      aws_iam_role.github["plan"].name == "cloudkube-github-plan" &&
      aws_iam_role.github["apply"].name == "cloudkube-github-apply" &&
      length(aws_iam_role_policy_attachment.plan_resources) == 0 &&
      length(aws_iam_role_policy_attachment.apply_resources) == 0 &&
      aws_iam_role.github["plan"].permissions_boundary == null &&
      aws_iam_role.github["apply"].permissions_boundary == null
    )
    error_message = "Roles must be distinct and default to backend-only without invented API policies or boundaries."
  }
  assert {
    condition = (
      length(aws_iam_openid_connect_provider.github) == 1 &&
      length(data.aws_iam_openid_connect_provider.github_existing) == 0 &&
      aws_iam_openid_connect_provider.github[0].url == "https://token.actions.githubusercontent.com" &&
      aws_iam_openid_connect_provider.github[0].client_id_list == toset(["sts.amazonaws.com"])
    )
    error_message = "Create mode must create only the exact GitHub issuer and STS audience."
  }
}

run "state_read_write_and_lock_permissions_are_separate" {
  command = plan

  assert {
    condition = (
      toset(one([for statement in jsondecode(aws_iam_role_policy.backend["plan"].policy).Statement : statement.Action if statement.Sid == "WorkloadState"])) == toset(["s3:GetObject"]) &&
      toset(one([for statement in jsondecode(aws_iam_role_policy.backend["apply"].policy).Statement : statement.Action if statement.Sid == "WorkloadState"])) == toset(["s3:GetObject", "s3:PutObject"])
    )
    error_message = "Plan may read state; only apply may write it. Neither receives state deletion."
  }
  assert {
    condition = alltrue([
      for role in ["plan", "apply"] :
      one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Resource if statement.Sid == "WorkloadState"]) == ["arn:aws:s3:::cloudkube-test-state-123456789012/workload/production/terraform.tfstate"] &&
      one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Resource if statement.Sid == "WorkloadLock"]) == ["arn:aws:s3:::cloudkube-test-state-123456789012/workload/production/terraform.tfstate.tflock"] &&
      toset(one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Action if statement.Sid == "WorkloadLock"])) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject"])
    ])
    error_message = "Both roles need exact lockfile operations, with no bucket-wide object access."
  }
  assert {
    condition = alltrue([
      for role in ["plan", "apply"] :
      toset(one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Condition.StringEquals["s3:prefix"] if statement.Sid == "ListWorkloadStatePrefix"])) == toset(["workload/production/terraform.tfstate", "workload/production/terraform.tfstate.tflock"])
    ])
    error_message = "Bucket listing must be scoped to workload state and lock prefixes."
  }
}

run "kms_permissions_are_key_service_and_object_scoped" {
  command = plan

  assert {
    condition = alltrue([
      for role in ["plan", "apply"] :
      toset(one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Action if statement.Sid == "StateEncryptionThroughS3"])) == toset(["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]) &&
      one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Resource if statement.Sid == "StateEncryptionThroughS3"]) == ["arn:aws:kms:us-east-1:123456789012:key/00000000-0000-4000-8000-000000000001"] &&
      one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Condition.StringEquals["kms:ViaService"] if statement.Sid == "StateEncryptionThroughS3"]) == "s3.us-east-1.amazonaws.com" &&
      toset(one([for statement in jsondecode(aws_iam_role_policy.backend[role].policy).Statement : statement.Condition.StringEquals["kms:EncryptionContext:aws:s3:arn"] if statement.Sid == "StateEncryptionThroughS3"])) == toset([
        "arn:aws:s3:::cloudkube-test-state-123456789012/workload/production/terraform.tfstate",
        "arn:aws:s3:::cloudkube-test-state-123456789012/workload/production/terraform.tfstate.tflock"
      ])
    ])
    error_message = "KMS permissions must cover only the state key through regional S3 and the two workload object contexts."
  }
}

run "bootstrap_protection_is_explicit_and_targeted" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for role in ["plan", "apply"] : [for statement in jsondecode(aws_iam_role_policy.guardrails[role].policy).Statement : statement.Effect == "Deny"]
    ]))
    error_message = "Guardrails must not introduce additional grants."
  }
  assert {
    condition = alltrue([
      for role in ["plan", "apply"] :
      toset(one([for statement in jsondecode(aws_iam_role_policy.guardrails[role].policy).Statement : statement.Resource if statement.Sid == "DenyBootstrapStateAccess"])) == toset([
        "arn:aws:s3:::cloudkube-test-state-123456789012/bootstrap/terraform.tfstate",
        "arn:aws:s3:::cloudkube-test-state-123456789012/bootstrap/terraform.tfstate.tflock"
      ]) &&
      toset(one([for statement in jsondecode(aws_iam_role_policy.guardrails[role].policy).Statement : statement.Resource if statement.Sid == "DenyBootstrapIdentityAdministration"])) == toset([
        "arn:aws:iam::123456789012:role/cloudkube-github-plan",
        "arn:aws:iam::123456789012:role/cloudkube-github-apply",
        "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      ])
    ])
    error_message = "Both roles must protect bootstrap state, both CI roles and the GitHub provider without a generic IAM/IRSA resource deny."
  }
  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.guardrails["plan"].policy).Statement : statement.NotAction if statement.Sid == "DenyPlanStateMutation"]) == ["s3:GetObject"] &&
      length([for statement in jsondecode(aws_iam_role_policy.guardrails["apply"].policy).Statement : statement if statement.Sid == "DenyPlanStateMutation"]) == 0 &&
      alltrue([for role in ["plan", "apply"] : length(aws_iam_role_policy.backend[role].policy) + length(aws_iam_role_policy.guardrails[role].policy) <= 10240])
    )
    error_message = "Plan state mutation must remain denied even with external policies; inline documents must fit IAM's aggregate role quota."
  }
  assert {
    condition = alltrue([
      for role in ["plan", "apply"] :
      one([for statement in jsondecode(aws_iam_role_policy.guardrails[role].policy).Statement : statement.Action if statement.Sid == "DenyStateVersionDeletion"]) == ["s3:DeleteObjectVersion"] &&
      one([for statement in jsondecode(aws_iam_role_policy.guardrails[role].policy).Statement : statement.Condition.StringNotEquals["kms:ViaService"] if statement.Sid == "DenyStateKeyOutsideS3"]) == "s3.us-east-1.amazonaws.com" &&
      toset(one([for statement in jsondecode(aws_iam_role_policy.guardrails[role].policy).Statement : statement.Condition.StringNotEquals["kms:EncryptionContext:aws:s3:arn"] if statement.Sid == "DenyStateKeyForOtherObjects"])) == toset([
        "arn:aws:s3:::cloudkube-test-state-123456789012/workload/production/terraform.tfstate",
        "arn:aws:s3:::cloudkube-test-state-123456789012/workload/production/terraform.tfstate.tflock"
      ])
    ])
    error_message = "Deletion protection and KMS restrictions must survive additional identity-policy allows."
  }
}

run "immutable_subject_and_existing_provider" {
  command = plan
  variables {
    github_subject_format             = "immutable"
    github_oidc_provider_mode         = "existing"
    github_existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }
  assert {
    condition = (
      length(aws_iam_openid_connect_provider.github) == 0 &&
      length(data.aws_iam_openid_connect_provider.github_existing) == 1 &&
      jsondecode(aws_iam_role.github["plan"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:eneiasbrumjr@57417495/cloudkube-eks-terraform-pipeline-enb@1016370567:ref:refs/heads/main" &&
      jsondecode(aws_iam_role.github["apply"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:eneiasbrumjr@57417495/cloudkube-eks-terraform-pipeline-enb@1016370567:environment:production"
    )
    error_message = "Existing mode must reuse only the declared provider and immutable subjects must retain both IDs and their job contexts."
  }
}

run "external_policies_and_boundary_are_protected" {
  command = plan
  variables {
    plan_resource_policy_arns       = ["arn:aws:iam::123456789012:policy/reviewed/CloudKubeRead"]
    apply_resource_policy_arns      = ["arn:aws:iam::123456789012:policy/reviewed/CloudKubeDeploy"]
    github_permissions_boundary_arn = "arn:aws:iam::123456789012:policy/reviewed/CloudKubeBoundary"
  }
  assert {
    condition = (
      aws_iam_role_policy_attachment.plan_resources["arn:aws:iam::123456789012:policy/reviewed/CloudKubeRead"].role == aws_iam_role.github["plan"].name &&
      aws_iam_role_policy_attachment.apply_resources["arn:aws:iam::123456789012:policy/reviewed/CloudKubeDeploy"].role == aws_iam_role.github["apply"].name &&
      alltrue([for role in ["plan", "apply"] : aws_iam_role.github[role].permissions_boundary == "arn:aws:iam::123456789012:policy/reviewed/CloudKubeBoundary"])
    )
    error_message = "External policies must attach to the selected role and the optional external boundary must cover both roles."
  }
  assert {
    condition = alltrue([
      for role in ["plan", "apply"] : alltrue([
        for arn in [
          "arn:aws:iam::123456789012:policy/reviewed/CloudKubeRead",
          "arn:aws:iam::123456789012:policy/reviewed/CloudKubeDeploy",
          "arn:aws:iam::123456789012:policy/reviewed/CloudKubeBoundary"
        ] : contains(one([for statement in jsondecode(aws_iam_role_policy.guardrails[role].policy).Statement : statement.Resource if statement.Sid == "DenyBootstrapIdentityAdministration"]), arn)
      ])
    ])
    error_message = "Neither CI role may administer its own or its peer's supplied policy or the boundary."
  }
}

run "reject_unconfirmed_subject_format" {
  command = plan
  variables { github_subject_format = "automatic" }
  expect_failures = [var.github_subject_format]
}

run "reject_ambiguous_provider_selection" {
  command = plan
  variables {
    github_existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }
  expect_failures = [var.github_existing_oidc_provider_arn]
}

run "reject_provider_from_other_account" {
  command = plan
  variables {
    github_oidc_provider_mode         = "existing"
    github_existing_oidc_provider_arn = "arn:aws:iam::999999999999:oidc-provider/token.actions.githubusercontent.com"
  }
  expect_failures = [var.github_existing_oidc_provider_arn]
}

run "reject_existing_provider_wrong_issuer" {
  command = plan
  variables {
    github_oidc_provider_mode         = "existing"
    github_existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }
  override_data {
    target = data.aws_iam_openid_connect_provider.github_existing[0]
    values = {
      url            = "https://other.example.com"
      client_id_list = ["sts.amazonaws.com"]
    }
  }
  expect_failures = [data.aws_iam_openid_connect_provider.github_existing[0]]
}

run "reject_existing_provider_without_sts_audience" {
  command = plan
  variables {
    github_oidc_provider_mode         = "existing"
    github_existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }
  override_data {
    target = data.aws_iam_openid_connect_provider.github_existing[0]
    values = {
      url            = "token.actions.githubusercontent.com"
      client_id_list = ["https://github.com/eneiasbrumjr"]
    }
  }
  expect_failures = [data.aws_iam_openid_connect_provider.github_existing[0]]
}

run "reject_aws_managed_administrator_policy" {
  command = plan
  variables { apply_resource_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
  expect_failures = [var.apply_resource_policy_arns]
}

run "reject_cross_account_policy_and_boundary" {
  command = plan
  variables {
    plan_resource_policy_arns       = ["arn:aws:iam::999999999999:policy/Read"]
    github_permissions_boundary_arn = "arn:aws:iam::999999999999:policy/Boundary"
  }
  expect_failures = [var.plan_resource_policy_arns, var.github_permissions_boundary_arn]
}

run "reject_oversized_combined_inline_policies" {
  command = plan
  variables {
    plan_resource_policy_arns = [
      for i in range(10) : "arn:aws:iam::123456789012:policy/${join("", [for n in range(400) : "a"])}/${join("", [for n in range(100) : "p"])}${i}"
    ]
    apply_resource_policy_arns = [
      for i in range(10) : "arn:aws:iam::123456789012:policy/${join("", [for n in range(400) : "a"])}/${join("", [for n in range(100) : "d"])}${i}"
    ]
  }
  expect_failures = [aws_iam_role_policy.guardrails["plan"], aws_iam_role_policy.guardrails["apply"]]
}
