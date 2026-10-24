locals {
  state_backend_common = {
    bucket              = aws_s3_bucket.state.id
    region              = var.aws_region
    encrypt             = true
    use_lockfile        = true
    kms_key_id          = aws_kms_key.state.arn
    allowed_account_ids = [var.aws_account_id]
  }
}

output "state_bucket_name" {
  description = "Name of the protected state bucket."
  value       = aws_s3_bucket.state.id
  sensitive   = false
}

output "state_bucket_arn" {
  description = "ARN of the protected state bucket."
  value       = aws_s3_bucket.state.arn
  sensitive   = false
}

output "kms_key_arn" {
  description = "ARN of the KMS key required by both state and lockfile uploads."
  value       = aws_kms_key.state.arn
  sensitive   = false
}

output "backend_config" {
  description = "Non-secret S3 backend parameters for the workload and the separate operator-only bootstrap state. Does not initialize or migrate either backend."
  value = {
    workload  = merge(local.state_backend_common, { key = var.workload_state_key })
    bootstrap = merge(local.state_backend_common, { key = var.bootstrap_state_key })
  }
  sensitive = false

  depends_on = [
    aws_s3_bucket_versioning.state,
    aws_s3_bucket_ownership_controls.state,
    aws_s3_bucket_public_access_block.state,
    aws_s3_bucket_server_side_encryption_configuration.state,
    aws_s3_bucket_policy.state,
  ]
}
