# CloudKube EKS Terraform Pipeline

[![Terraform](https://img.shields.io/badge/Terraform-1.6%2B-623CE4?logo=terraform)](https://developer.hashicorp.com/terraform)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Terraform configuration for provisioning a baseline AWS EKS environment with a custom VPC, managed node group, core EKS add-ons, IRSA support, VPC Flow Logs, and GitHub Actions automation.

This repository is intended as a credible starting point for an EKS foundation, not a complete platform. It favors readable Terraform, explicit inputs, and practical defaults over large abstractions.

## What This Repository Includes

- Custom VPC with public and private subnets across multiple availability zones
- Internet gateway, optional NAT gateways, and subnet tags for Kubernetes load balancers
- EKS cluster with managed node group in private subnets
- Configurable control plane logging
- Optional EKS secrets encryption with AWS KMS
- Optional IAM OIDC provider for IRSA
- Managed EKS add-ons:
  `vpc-cni`, `kube-proxy`, `coredns`, `aws-ebs-csi-driver`
- VPC Flow Logs to CloudWatch Logs
- GitHub Actions workflow for `fmt`, `validate`, `tfsec`, plan, apply, and terraform-docs updates
- Pre-commit, TFLint, and terraform-docs configuration for contributor workflows

## What It Does Not Include

- A remote-state bucket or DynamoDB lock table
- Workload add-ons such as AWS Load Balancer Controller, Cluster Autoscaler, ExternalDNS, or Metrics Server
- Helm releases, Argo CD, Flux, or application deployment manifests
- Opinionated RBAC, Pod Security Standards, network policies, or admission controllers
- OIDC infrastructure in AWS for GitHub Actions
- Cost automation such as scheduled scale-down or autoscaler policies beyond managed node group scaling

## Current Security Posture

Implemented in code:

- Worker nodes run in private subnets
- EKS secrets encryption can be enabled with a dedicated KMS key
- IRSA can be enabled through an IAM OIDC provider
- Control plane logs are configurable and sent to CloudWatch Logs
- VPC Flow Logs can be enabled
- SSH access to nodes is disabled unless an EC2 key pair is explicitly provided

Important limitations:

- The default API endpoint configuration still allows public access and defaults to `0.0.0.0/0` for convenience in non-production use. Restrict `cluster_endpoint_public_access_cidrs` or disable public access before real deployments.
- The repository does not create workload IAM roles beyond the EBS CSI driver role.
- The custom network ACL is permissive and should not be treated as a hardened network boundary.
- The backend configuration is only a commented example; production state management must be provisioned separately.

## Terraform Layout

```text
.
├── .github/workflows/terraform-eks-pipeline.yml
├── infra
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── modules
│       ├── eks
│       └── vpc
├── .pre-commit-config.yaml
├── .terraform-docs.yml
├── .tflint.hcl
└── README.md
```

## Prerequisites

- Terraform `>= 1.6`
- AWS CLI v2
- AWS credentials with permission to manage VPC, IAM, CloudWatch, KMS, and EKS resources
- Optional:
  `kubectl`, `pre-commit`, `tflint`, `tfsec`, `terraform-docs`

## Quick Start

```bash
git clone https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb.git
cd cloudkube-eks-terraform-pipeline-enb/infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

After apply:

```bash
aws eks update-kubeconfig --region us-east-1 --name cloudkube-eks-dev
kubectl get nodes
```

## Deployment Notes

- The root module currently defaults to Kubernetes `1.29`.
- The EKS control plane is attached to private subnets only.
- The managed node group also uses private subnets only.
- For production use, provision remote state first and replace the commented example in `infra/backend.tf`.
- Review `infra/terraform.tfvars.example` carefully before first apply. Several example values are intentionally convenience-oriented for local testing.

## CI/CD

The GitHub Actions workflow does the following:

- On pull requests:
  `terraform fmt -check`, `terraform validate`, `tfsec`, and a Terraform plan for same-repository PRs
- On pushes to `main`:
  Terraform plan and apply in `infra/`
- On same-repository pull requests:
  terraform-docs updates can be pushed back to the branch

Authentication behavior:

- Preferred:
  GitHub OIDC with `AWS_ROLE_ARN`
- Backward-compatible fallback:
  `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

The repository does not provision the AWS-side IAM role for GitHub OIDC. That must exist before OIDC-based CI can work.

## Local Contributor Workflow

```bash
pre-commit install
pre-commit run --all-files
cd infra
terraform fmt -recursive
terraform validate
```

If you want to refresh the Terraform tables locally:

```bash
terraform-docs infra
```

## Included vs. Claimed Features

This repository intentionally does not claim the following as fully implemented:

- "Enterprise-grade" or "production-ready" as a blanket guarantee
- Full AWS Well-Architected alignment
- Comprehensive observability
- Comprehensive security controls
- Self-managing remote state
- Cost optimization automation

What it does provide is a solid, reviewable EKS infrastructure baseline that can be extended for a real platform.

## Additional Docs

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY_AUDIT.md](SECURITY_AUDIT.md)
- [PROJECT_STATUS.md](PROJECT_STATUS.md)
- [CHANGELOG.md](CHANGELOG.md)

## License

MIT. See [LICENSE](LICENSE).

## Terraform Documentation

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
