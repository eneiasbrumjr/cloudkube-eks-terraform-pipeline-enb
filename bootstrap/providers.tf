terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project    = var.name_prefix
      Component  = "bootstrap"
      ManagedBy  = "Terraform"
      Repository = "cloudkube-eks-terraform-pipeline-enb"
    }
  }
}
