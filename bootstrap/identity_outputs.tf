output "github_actions_variables" {
  description = "Non-secret Actions variable values. Roles still need reviewed API policies and GitHub environment protections before cloud jobs are useful."
  value = {
    AWS_ACCOUNT_ID     = var.aws_account_id
    AWS_REGION         = var.aws_region
    AWS_PLAN_ROLE_ARN  = aws_iam_role.github["plan"].arn
    AWS_APPLY_ROLE_ARN = aws_iam_role.github["apply"].arn
  }
}

output "github_oidc_provider_arn" {
  description = "Created or explicitly reused GitHub OIDC provider. Existing mode does not adopt or modify it."
  value       = local.github_provider_arn
}

output "github_trust_subjects" {
  description = "Exact subjects generated from the explicitly selected format; confirm them against the repository's actual settings before use."
  value       = local.github_subjects
}

output "github_resource_api_policies_configured" {
  description = "Whether external policy ARNs were supplied, not evidence of their sufficiency or least privilege. False means backend-only permissions from this bootstrap."
  value = {
    plan  = length(var.plan_resource_policy_arns) > 0
    apply = length(var.apply_resource_policy_arns) > 0
  }
}
