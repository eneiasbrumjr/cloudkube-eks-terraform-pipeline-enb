# ------------------------------------------------------------------------------
# Terraform Backend
# ------------------------------------------------------------------------------
#
# This backend configuration is commented out by default to allow for local
# execution without requiring an S3 bucket. To use this with a remote backend,
# uncomment the following lines and replace the placeholder values.
#
# Best Practices:
# - Enable versioning on the S3 bucket
# - Enable encryption at rest using KMS
# - Use DynamoDB for state locking to prevent concurrent modifications
# - Restrict access to the bucket using IAM policies and bucket policies
#
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket-name"
#     key            = "eks/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID"
#     dynamodb_table = "terraform-state-locks"
#
#     # Enable versioning for state file history
#     versioning     = true
#
#     # Additional security measures
#     acl            = "private"
#   }
# }
