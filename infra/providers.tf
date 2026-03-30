# ------------------------------------------------------------------------------
# Terraform Providers
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  # This is a best practice for cost allocation, resource management, and compliance
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "cloudkube-eks-terraform-pipeline-enb"
    }
  }
}
