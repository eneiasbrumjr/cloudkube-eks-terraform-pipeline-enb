# EKS Terraform Pipeline

This repository contains Terraform code to provision an Amazon EKS (Elastic Kubernetes Service) cluster and a CI/CD pipeline to manage its deployment.

## Overview

[Provide a more detailed description of the project here. What is its purpose? What does the pipeline do?]

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)
- [AWS CLI](https://aws.amazon.com/cli/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Setup

1. **Clone the repository:**

   ```bash
   git clone git@github.com:eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb.git
   cd cloudkube-eks-terraform-pipeline-enb
   ```

2. **Configure AWS Credentials:**
   Ensure your AWS credentials are configured correctly.

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

## Usage

1. **Plan the infrastructure:**

   ```bash
   terraform plan
   ```

2. **Apply the changes:**
   ```bash
   terraform apply
   ```

## Pipeline

[Describe the CI/CD pipeline here. What triggers it? What are the stages?]

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
