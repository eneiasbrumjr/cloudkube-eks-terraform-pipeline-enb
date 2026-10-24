variable "github_oidc_provider_mode" {
  description = "Explicitly create the account's GitHub OIDC provider or reuse an existing one after issuer/audience checks."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["create", "existing"], var.github_oidc_provider_mode)
    error_message = "Choose github_oidc_provider_mode = create or existing after checking the account's provider ownership."
  }
}

variable "github_existing_oidc_provider_arn" {
  description = "Existing GitHub provider ARN in aws_account_id. Required only in existing mode; its configuration is read, not adopted."
  type        = string
  default     = null

  validation {
    condition = var.github_oidc_provider_mode == "existing" ? (
      var.github_existing_oidc_provider_arn == "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
    ) : var.github_existing_oidc_provider_arn == null
    error_message = "Existing mode requires the exact GitHub OIDC provider ARN in aws_account_id; create mode requires a null existing ARN."
  }
}

variable "github_subject_format" {
  description = "Confirmed GitHub subject format, legacy or immutable. No default: verify the repository's OIDC settings before use. Custom subject templates are outside this module's contract."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["legacy", "immutable"], var.github_subject_format)
    error_message = "Explicitly choose legacy or immutable after confirming the repository's actual subject format."
  }
}

variable "github_repository" {
  description = "Exact owner/repository trusted by both roles. Defaults identify this repository; forks/transfers require reviewed values and IDs."
  type        = string
  default     = "eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$", var.github_repository)) && length(var.github_repository) <= 140
    error_message = "Provide one exact GitHub owner/repository, without wildcards, URLs, or subject delimiters."
  }
}

variable "github_repository_id" {
  description = "Confirmed immutable repository ID; the default belongs to eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb."
  type        = string
  default     = "1016370567"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]{0,19}$", var.github_repository_id))
    error_message = "github_repository_id must be a positive decimal GitHub repository ID."
  }
}

variable "github_repository_owner_id" {
  description = "Confirmed immutable repository owner ID; the default belongs to eneiasbrumjr."
  type        = string
  default     = "57417495"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]{0,19}$", var.github_repository_owner_id))
    error_message = "github_repository_owner_id must be a positive decimal GitHub owner ID."
  }
}

variable "plan_resource_policy_arns" {
  description = "Operator-reviewed customer-managed policies for infrastructure reads. Empty means backend-only; ARN validation does not certify policy contents or effective permissions."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = length(var.plan_resource_policy_arns) <= 10 && alltrue([
      for arn in var.plan_resource_policy_arns :
      can(regex("^arn:aws:iam::${var.aws_account_id}:policy/([A-Za-z0-9+=,.@_-]+/)*[A-Za-z0-9+=,.@_-]+$", arn)) && length(arn) <= 2048
    ])
    error_message = "Supply at most ten explicit customer-managed policy ARNs in aws_account_id; AWS-managed policies and wildcards are not accepted."
  }
}

variable "apply_resource_policy_arns" {
  description = "Operator-reviewed customer-managed policies for workload deployment. Empty means backend-only; no AdministratorAccess fallback or complete deployment policy is generated."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = length(var.apply_resource_policy_arns) <= 10 && alltrue([
      for arn in var.apply_resource_policy_arns :
      can(regex("^arn:aws:iam::${var.aws_account_id}:policy/([A-Za-z0-9+=,.@_-]+/)*[A-Za-z0-9+=,.@_-]+$", arn)) && length(arn) <= 2048
    ])
    error_message = "Supply at most ten explicit customer-managed policy ARNs in aws_account_id; AWS-managed policies and wildcards are not accepted."
  }
}

variable "github_permissions_boundary_arn" {
  description = "Optional operator-managed boundary for both GitHub roles. Must permit the required backend/API operations; this bootstrap neither creates nor validates its policy contents."
  type        = string
  default     = null

  validation {
    condition = var.github_permissions_boundary_arn == null ? true : (
      can(regex("^arn:aws:iam::${var.aws_account_id}:policy/([A-Za-z0-9+=,.@_-]+/)*[A-Za-z0-9+=,.@_-]+$", var.github_permissions_boundary_arn)) && length(var.github_permissions_boundary_arn) <= 2048
    )
    error_message = "The optional boundary must be an explicit customer-managed policy ARN in aws_account_id."
  }
}
