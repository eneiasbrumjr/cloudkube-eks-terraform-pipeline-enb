# This root is operated separately from workload CI. These roles receive backend
# permissions by default; operator-reviewed API policies are explicit inputs.
locals {
  github_issuer = "token.actions.githubusercontent.com"
  github_provider_arn = one(concat(
    aws_iam_openid_connect_provider.github[*].arn,
    data.aws_iam_openid_connect_provider.github_existing[*].arn
  ))
  github_repository_parts = split("/", var.github_repository)
  github_subject_prefix = var.github_subject_format == "immutable" ? (
    "repo:${local.github_repository_parts[0]}@${var.github_repository_owner_id}/${try(local.github_repository_parts[1], "")}@${var.github_repository_id}"
  ) : "repo:${var.github_repository}"
  github_subjects = {
    plan  = "${local.github_subject_prefix}:ref:refs/heads/main"
    apply = "${local.github_subject_prefix}:environment:production"
  }
  github_role_names = {
    plan  = "${var.name_prefix}-github-plan"
    apply = "${var.name_prefix}-github-apply"
  }
  github_trust_conditions = {
    for role in keys(local.github_role_names) : role => merge({
      "${local.github_issuer}:aud"                 = "sts.amazonaws.com"
      "${local.github_issuer}:sub"                 = local.github_subjects[role]
      "${local.github_issuer}:ref"                 = "refs/heads/main"
      "${local.github_issuer}:repository_id"       = var.github_repository_id
      "${local.github_issuer}:repository_owner_id" = var.github_repository_owner_id
    }, role == "apply" ? { "${local.github_issuer}:environment" = "production" } : {})
  }

  workload_state_arn = "${aws_s3_bucket.state.arn}/${var.workload_state_key}"
  workload_lock_arn  = "${local.workload_state_arn}.tflock"
  bootstrap_object_arns = [
    "${aws_s3_bucket.state.arn}/${var.bootstrap_state_key}",
    "${aws_s3_bucket.state.arn}/${var.bootstrap_state_key}.tflock"
  ]
  state_crypto_actions = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
  state_crypto_context = [local.workload_state_arn, local.workload_lock_arn]
  state_s3_service     = "s3.${var.aws_region}.amazonaws.com"
  protected_identity_arns = concat(
    [for name in values(local.github_role_names) : "arn:aws:iam::${var.aws_account_id}:role/${name}"],
    ["arn:aws:iam::${var.aws_account_id}:oidc-provider/${local.github_issuer}"],
    sort(tolist(setunion(var.plan_resource_policy_arns, var.apply_resource_policy_arns))),
    var.github_permissions_boundary_arn == null ? [] : [var.github_permissions_boundary_arn]
  )

  backend_policy_documents = {
    for role in keys(local.github_role_names) : role => jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ListWorkloadStatePrefix"
          Effect   = "Allow"
          Action   = ["s3:ListBucket"]
          Resource = [aws_s3_bucket.state.arn]
          Condition = {
            StringEquals = { "s3:prefix" = [var.workload_state_key, "${var.workload_state_key}.tflock"] }
          }
        },
        {
          Sid      = "WorkloadState"
          Effect   = "Allow"
          Action   = role == "plan" ? ["s3:GetObject"] : ["s3:GetObject", "s3:PutObject"]
          Resource = [local.workload_state_arn]
        },
        {
          Sid      = "WorkloadLock"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
          Resource = [local.workload_lock_arn]
        },
        {
          Sid      = "StateEncryptionThroughS3"
          Effect   = "Allow"
          Action   = local.state_crypto_actions
          Resource = [aws_kms_key.state.arn]
          Condition = {
            StringEquals = {
              "kms:ViaService"                   = local.state_s3_service
              "kms:EncryptionContext:aws:s3:arn" = local.state_crypto_context
            }
          }
        }
      ]
    })
  }

  # These targeted denies remain in effect if an external API policy grants too
  # much on these resources. They are not a universal anti-escalation boundary.
  # Resource-policy grants and indirect escalation still require operator review.
  guardrail_policy_documents = {
    for role in keys(local.github_role_names) : role => jsonencode({
      Version = "2012-10-17"
      Statement = concat([
        {
          Sid      = "DenyBootstrapStateAccess"
          Effect   = "Deny"
          Action   = ["s3:*"]
          Resource = local.bootstrap_object_arns
        },
        {
          Sid      = "DenyWorkloadStateDeletion"
          Effect   = "Deny"
          Action   = ["s3:DeleteObject"]
          Resource = [local.workload_state_arn]
        },
        {
          Sid      = "DenyStateVersionDeletion"
          Effect   = "Deny"
          Action   = ["s3:DeleteObjectVersion"]
          Resource = ["${aws_s3_bucket.state.arn}/*"]
        },
        {
          Sid       = "DenyStateBucketAdministration"
          Effect    = "Deny"
          NotAction = ["s3:Get*", "s3:List*"]
          Resource  = [aws_s3_bucket.state.arn]
        },
        {
          Sid       = "DenyStateKeyAdministration"
          Effect    = "Deny"
          NotAction = concat(local.state_crypto_actions, ["kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags"])
          Resource  = [aws_kms_key.state.arn]
        },
        {
          Sid       = "DenyStateKeyOutsideS3"
          Effect    = "Deny"
          Action    = local.state_crypto_actions
          Resource  = [aws_kms_key.state.arn]
          Condition = { StringNotEquals = { "kms:ViaService" = local.state_s3_service } }
        },
        {
          Sid       = "DenyStateKeyForOtherObjects"
          Effect    = "Deny"
          Action    = local.state_crypto_actions
          Resource  = [aws_kms_key.state.arn]
          Condition = { StringNotEquals = { "kms:EncryptionContext:aws:s3:arn" = local.state_crypto_context } }
        },
        {
          Sid       = "DenyBootstrapIdentityAdministration"
          Effect    = "Deny"
          NotAction = ["iam:Get*", "iam:List*"]
          Resource  = distinct(local.protected_identity_arns)
        }
        ], role == "plan" ? [
        {
          Sid       = "DenyPlanStateMutation"
          Effect    = "Deny"
          NotAction = ["s3:GetObject"]
          Resource  = [local.workload_state_arn]
        }
      ] : [])
    })
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_mode == "create" ? 1 : 0

  url            = "https://${local.github_issuer}"
  client_id_list = ["sts.amazonaws.com"]
  # Provider 5.100 supports omitting thumbprints; do not pin a copied certificate.
  tags = { Name = "${var.name_prefix}-github-oidc" }

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_openid_connect_provider" "github_existing" {
  count = var.github_oidc_provider_mode == "existing" ? 1 : 0
  arn   = var.github_existing_oidc_provider_arn

  lifecycle {
    postcondition {
      condition     = trimsuffix(trimprefix(self.url, "https://"), "/") == local.github_issuer
      error_message = "The existing provider must have the exact GitHub Actions issuer."
    }
    postcondition {
      condition     = contains(self.client_id_list, "sts.amazonaws.com")
      error_message = "The existing provider must include sts.amazonaws.com as an audience."
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.github_role_names

  name                 = each.value
  description          = "GitHub ${each.key}: exact repository/main trust and scoped state access"
  max_session_duration = 3600
  permissions_boundary = var.github_permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = local.github_trust_conditions[each.key] }
    }]
  })
  tags = { Name = each.value, Purpose = "github-${each.key}" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy" "backend" {
  for_each = local.github_role_names

  name   = "workload-state"
  role   = aws_iam_role.github[each.key].name
  policy = local.backend_policy_documents[each.key]
}

resource "aws_iam_role_policy" "guardrails" {
  for_each = local.github_role_names

  name   = "bootstrap-protection"
  role   = aws_iam_role.github[each.key].name
  policy = local.guardrail_policy_documents[each.key]

  lifecycle {
    precondition {
      condition     = length(local.backend_policy_documents[each.key]) + length(local.guardrail_policy_documents[each.key]) <= 10240
      error_message = "Combined inline role policies exceed IAM's 10,240-character limit. Reduce supplied policy ARNs/key lengths or redesign the reviewed permissions."
    }
  }
}

resource "aws_iam_role_policy_attachment" "plan_resources" {
  for_each = var.plan_resource_policy_arns

  role       = aws_iam_role.github["plan"].name
  policy_arn = each.value

  depends_on = [aws_iam_role_policy.guardrails]
}

resource "aws_iam_role_policy_attachment" "apply_resources" {
  for_each = var.apply_resource_policy_arns

  role       = aws_iam_role.github["apply"].name
  policy_arn = each.value

  depends_on = [aws_iam_role_policy.guardrails]
}
