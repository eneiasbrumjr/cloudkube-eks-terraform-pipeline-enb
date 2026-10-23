# ------------------------------------------------------------------------------
# Terraform Backend
# ------------------------------------------------------------------------------
#
# Example only: keep this configuration commented for local, credential-free
# validation. Remote-state resources must already exist before activating it.
# Read ../REMOTE_STATE.md before initializing or migrating any real state.
#
# Terraform 1.12.2 supports native S3 lockfiles. New setups do not need DynamoDB.
# A one-time operator must prepare versioning, public-access blocking, HTTPS-only
# access, an enabled SSE-KMS key, and scoped state/lockfile permissions separately.
# Credentials belong in the AWS credential chain, never in backend configuration.
#
# Complete example: the manual workflow runs init without -backend-config.
# Deliberately activate and review these non-secret destination fields for CI:
# terraform {
#   backend "s3" {
#     bucket              = "your-existing-terraform-state-bucket"
#     key                 = "cloudkube/production/terraform.tfstate"
#     region              = "us-east-1"
#     encrypt             = true
#     use_lockfile        = true
#     kms_key_id          = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
#     allowed_account_ids = ["123456789012"]
#   }
# }
#
# Replace every placeholder. Use the default Terraform workspace and a distinct
# key per environment. Nothing in this file creates resources or migrates state.
# A local partial-config alternative is documented in ../REMOTE_STATE.md; its
# operator-owned file is not supplied to the current GitHub Actions runner.
