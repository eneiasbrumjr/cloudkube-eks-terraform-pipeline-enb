# ------------------------------------------------------------------------------
# Terraform Backend
# ------------------------------------------------------------------------------
#
# This backend configuration is commented out by default to allow for local
# execution without requiring an S3 bucket. To use this with a remote backend,
# uncomment the following lines and replace the bucket and region with your own.
#
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket-name"
#     key            = "cloudkube-eks/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "your-terraform-lock-table"
#   }
# }
