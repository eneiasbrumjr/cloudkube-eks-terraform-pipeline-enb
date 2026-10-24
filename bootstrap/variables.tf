variable "aws_account_id" {
  description = "Expected 12-digit AWS account ID. The provider refuses credentials for another account."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "aws_region" {
  description = "Commercial AWS region for the state bucket and KMS key. Other AWS partitions are outside this bootstrap."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[1-9][0-9]*$", var.aws_region)) && !startswith(var.aws_region, "cn-")
    error_message = "Use a commercial AWS region code such as us-east-1; China, GovCloud and isolated partitions are not supported."
  }
}

variable "name_prefix" {
  description = "Short prefix for bootstrap resource names and tags."
  type        = string
  default     = "cloudkube"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3 to 32 lowercase letters, digits or hyphens, with alphanumeric first and last characters."
  }
}

variable "state_bucket_name" {
  description = "Globally unique general-purpose S3 bucket name to create. This bootstrap uses lowercase letters, digits and hyphens only."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.state_bucket_name)) &&
      alltrue([for prefix in ["xn--", "sthree-", "amzn-s3-demo-"] : !startswith(var.state_bucket_name, prefix)]) &&
      alltrue([for suffix in ["-s3alias", "--ol-s3", "--x-s3", "--table-s3", "-an"] : !endswith(var.state_bucket_name, suffix)])
    )
    error_message = "Use a 3 to 63 character lowercase/hyphen S3 bucket name without AWS-reserved prefixes or suffixes. Account-regional namespaces are outside this provider baseline."
  }
}

variable "workload_state_key" {
  description = "Explicit relative S3 object key for the EKS state. No wildcard, empty, dot or parent-directory segments; leave room for the .tflock suffix."
  type        = string
  nullable    = false

  validation {
    condition = (
      length(var.workload_state_key) <= 1017 &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]*$", var.workload_state_key)) &&
      alltrue([for segment in split("/", var.workload_state_key) : !contains(["", ".", ".."], segment)])
    )
    error_message = "workload_state_key must be a relative ASCII key of at most 1017 characters using letters, digits, dot, underscore, hyphen and slash, without wildcard or empty/dot/parent segments."
  }

  validation {
    condition = (
      var.workload_state_key != var.bootstrap_state_key &&
      "${var.workload_state_key}.tflock" != var.bootstrap_state_key &&
      var.workload_state_key != "${var.bootstrap_state_key}.tflock"
    )
    error_message = "The workload state, bootstrap state and their .tflock objects must have distinct keys."
  }
}

variable "bootstrap_state_key" {
  description = "Separate operator-only S3 key for a future manual migration of this bootstrap's local state."
  type        = string
  default     = "bootstrap/terraform.tfstate"
  nullable    = false

  validation {
    condition = (
      length(var.bootstrap_state_key) <= 1017 &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]*$", var.bootstrap_state_key)) &&
      alltrue([for segment in split("/", var.bootstrap_state_key) : !contains(["", ".", ".."], segment)])
    )
    error_message = "bootstrap_state_key must be a relative ASCII key of at most 1017 characters using letters, digits, dot, underscore, hyphen and slash, without wildcard or empty/dot/parent segments."
  }
}
