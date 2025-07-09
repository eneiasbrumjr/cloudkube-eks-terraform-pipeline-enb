# CloudKube EKS Terraform Pipeline

This project provides a complete and working Terraform and GitHub Actions setup to provision an AWS EKS cluster.

## Features

- **Terraform EKS Provisioning**: Creates a new VPC with public and private subnets, security groups, and an EKS cluster with managed node groups.
- **GitHub Actions CI/CD**: A pipeline that automates `terraform fmt`, `validate`, `plan`, and `apply`.
- **Well-Structured**: The project is organized into a clean and easy-to-understand folder structure with local modules for VPC and EKS.
- **Best Practices**: Follows AWS and Terraform best practices for security and maintainability.

## Terraform Documentation

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## Prerequisites

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) >= 1.5
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
- An AWS account with the necessary permissions to create the resources.

## Local Usage

1. **Clone the repository:**

   ```sh
   git clone https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb.git
   cd cloudkube-eks-terraform-pipeline-enb/infra
   ```

2. **Configure AWS Credentials:**

   Make sure your AWS credentials are configured correctly. You can do this by setting the following environment variables:

   ```sh
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_REGION="us-east-1"
   ```

3. **Initialize Terraform:**

   ```sh
   terraform init
   ```

4. **Plan the deployment:**

   ```sh
   terraform plan
   ```

5. **Apply the changes:**

   ```sh
   terraform apply
   ```

## GitHub Actions CI/CD

The CI/CD pipeline is defined in `.github/workflows/terraform-eks-pipeline.yml`. It will trigger on every push or pull request to the `main` branch.

### Secrets

The pipeline requires the following secrets to be configured in your GitHub repository settings:

- `AWS_ACCESS_KEY_ID`: Your AWS access key ID.
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key.
- `AWS_REGION`: The AWS region where you want to deploy the resources (e.g., `us-east-1`).

### Pipeline Stages

- **Checkout**: Checks out the code from the repository.
- **Configure AWS Credentials**: Configures the AWS credentials for Terraform.
- **Setup Terraform**: Sets up the specified version of Terraform.
- **Terraform Init**: Initializes the Terraform backend.
- **Terraform Format**: Checks if the code is correctly formatted.
- **Terraform Validate**: Validates the Terraform configuration.
- **Terraform Plan**: Creates an execution plan (only for pull requests).
- **Terraform Apply**: Applies the changes to the infrastructure (only for pushes to `main`).

## Terraform State

The Terraform state is configured to be stored locally by default. For production environments, it is recommended to use a remote backend like Amazon S3. The `infra/backend.tf` file contains a commented-out S3 backend configuration that you can use as a starting point.
