# ------------------------------------------------------------------------------
# Terraform Backend
# ------------------------------------------------------------------------------
#
# This backend configuration stays commented so the repository can be initialized
# locally without requiring pre-created remote state resources.
#
# For team or production use, provision the S3 bucket and DynamoDB table
# separately, then uncomment and replace the placeholder values below.
#
# Recommended hardening for the backing resources:
# - Enable S3 bucket versioning
# - Encrypt the bucket with SSE-KMS
# - Block public access on the bucket
# - Restrict access with IAM and bucket policies
# - Enable DynamoDB point-in-time recovery on the lock table
#
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "eks/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
#     dynamodb_table = "terraform-state-locks"
#   }
# }
