# ------------------------------------------------------------------------------
# Terraform Providers
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  # This is a best practice for cost allocation, resource management, and compliance
  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
        Repository  = "cloudkube-eks-terraform-pipeline-enb"
      },
      var.additional_tags
    )
  }
}
