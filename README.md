# CloudKube EKS Terraform Pipeline

[![Terraform](https://img.shields.io/badge/Terraform-1.11%2B-623CE4?logo=terraform)](https://developer.hashicorp.com/terraform)
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
- GitHub Actions workflow for `fmt`, `validate`, tests with mocked providers, Trivy reports, manual plan/apply, and generated documentation
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
- Kubernetes API access is private by default; public access requires explicit, restricted IPv4 CIDRs
- Root input validation rejects disabled access in both modes, public access without CIDRs, malformed CIDRs, IPv6 ranges, and unrestricted `/0` ranges
- Public and private subnets disable automatic public IPv4 assignment
- EKS secrets encryption can be enabled with a dedicated KMS key
- IRSA can be enabled through an IAM OIDC provider
- Control plane logs are configurable and sent to CloudWatch Logs
- VPC Flow Logs can be enabled
- SSH access to nodes is disabled unless an EC2 key pair is explicitly provided

Important limitations:

- Administration of the private API requires VPC-connected routing, DNS, authorized Kubernetes credentials, and security-group rules allowing HTTPS from the administration host or network. This repository does not provision that access path.
- Security-group egress remains broad. The custom node security group is an optional SSH source, not a group automatically attached to managed nodes; EKS creates an additional cluster security group. See [SECURITY_AUDIT.md](SECURITY_AUDIT.md) before treating these rules as the effective network policy.
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
│   ├── tests
│   ├── variables.tf
│   └── modules
│       ├── eks
│       └── vpc
├── scripts/scan-terraform.sh
├── .pre-commit-config.yaml
├── .terraform-docs.yml
├── .tflint.hcl
└── README.md
```

## Prerequisites

- Terraform `>= 1.11, < 2.0` (`1.12.2` is used in CI)
- AWS CLI v2
- AWS credentials with permission to manage VPC, IAM, CloudWatch, KMS, and EKS resources
- Optional:
  `kubectl`, `pre-commit >= 4.4.0`, `tflint`, `Trivy 0.76.1`, `terraform-docs`

## Quick Start

These defaults target a new cluster. Review the [compatibility and migration notes](COMPATIBILITY.md) before changing an existing environment. Configure remote state and an administration access path before applying.

```bash
git clone https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb.git
cd cloudkube-eks-terraform-pipeline-enb/infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

After apply, run these commands from a host with access to the private endpoint:

```bash
aws eks update-kubeconfig --region us-east-1 --name cloudkube-eks-dev
kubectl get nodes
```

`update-kubeconfig` configures credentials and the endpoint address; it does not create network connectivity. For an intentional public-access setup, set `cluster_endpoint_public_access = true` and supply your real trusted IPv4 egress CIDRs in `cluster_endpoint_public_access_cidrs`. Keep private access enabled so nodes can use the private API. An example documentation address such as `203.0.113.10/32` must be replaced before use. See the [AWS endpoint access requirements](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html).

## Deployment Notes

- The root module defaults to Kubernetes `1.36`, reviewed against the AWS support calendar on 2026-10-23. The managed node group explicitly uses `AL2023_x86_64_STANDARD`; select compatible x86_64 instance types. See [COMPATIBILITY.md](COMPATIBILITY.md) for support dates, provider evidence, and existing-cluster migration limits.
- The EKS control plane is attached to private subnets only.
- The managed node group also uses private subnets only.
- Public subnets retain their internet-gateway route and load-balancer discovery tags. Disabling automatic public IPs does not remove those routes; the NAT gateway continues to use its explicitly allocated Elastic IP.
- Keep NAT enabled unless a tested alternative supplies the required AWS-service and container-registry access. A private Kubernetes API endpoint alone does not provide those dependencies.
- For production use, provision remote state first and replace the commented example in `infra/backend.tf`.
- Review `infra/terraform.tfvars.example` before first apply. Its historical cost estimates have not been refreshed in this compatibility review.

## CI/CD

The workflow separates checks that need no AWS credentials from manual cloud operations.

| Trigger | Behavior |
| --- | --- |
| Pull request targeting `main`, or push to `main`, matching the workflow path filters | Format check, backend-free initialization, Terraform validation, tests with mocked providers, advisory security report, and documentation generation |
| Manual run with `operation: validate` (default) | The same checks, without cloud authentication |
| Manual run on `main` with `operation: plan` | Checks, AWS authentication, remote-state verification, and Terraform plan |
| Manual run on `main` with `operation: apply` | Checks, AWS authentication, remote-state verification, plan, and apply through the `production` environment |

A push or pull request never starts a cloud plan or apply. Test runs explicitly use `command = plan` with mocked AWS and TLS providers; they evaluate configuration without querying an AWS account. Format failures, initialization errors, validation errors, failed tests, and cloud plan errors fail their jobs.

### Reports and generated documentation

- The Trivy configuration scan remains **advisory**: findings at medium severity or above are reported without blocking this infrastructure baseline.
- Trivy runs after Terraform validation through the same script used by the local security hook. Its version is pinned, and each scan uses an empty temporary cache to select bundled checks. Parsing diagnostics, scanner execution failures, and a missing or invalid SARIF report fail the job. A successful security job does not mean there are no findings.
- Generated scan reports are uploaded as `trivy-results` artifacts. Successful push and manual scans also upload SARIF to GitHub Security; pull requests use the artifact without requiring a write-capable token. A failed scan cannot publish a partial analysis to GitHub Security.
- Validation outcomes and the security finding count appear in the workflow summary.
- Terraform documentation is generated as a `terraform-documentation` artifact. The workflow does not commit or push generated changes into a branch.
- Saved Terraform plans remain in the apply runner and are not published as artifacts.

### Manual cloud operations

Before selecting `plan` or `apply` in **Actions > Terraform EKS Pipeline > Run workflow**:

1. Provision durable remote state and configure an S3 backend in `infra/backend.tf`. The workflow requires an initialized S3 backend before planning.
2. Configure AWS authentication and review the Terraform inputs.
3. Select `main` and the intended operation. Other branches run the local checks but skip cloud jobs.
4. Review the `production` environment settings before using `apply`. Required reviewers and deployment protections must be configured separately.

The backend in this repository is a commented example. Cloud operations remain blocked until the backend is configured. The backend check verifies its initialized type, not the bucket's locking, access policy, or recovery configuration.

Authentication retains the existing options:

- Preferred: GitHub OpenID Connect (OIDC), with the `AWS_ROLE_ARN` secret.
- Compatibility fallback: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets.
- Region: `AWS_REGION` secret, defaulting to `us-east-1`.

Only the manual cloud jobs receive these settings and request an OIDC token. The repository does not provision the AWS identity resources or remote-state storage.

See [TEST_RESULTS.md](TEST_RESULTS.md) for executed checks and their limits.

## Local Contributor Workflow

Install the local tools described in [CONTRIBUTING.md](CONTRIBUTING.md), including Trivy `0.76.1` and pre-commit `>= 4.4.0`.

```bash
pre-commit install
terraform -chdir=infra init -backend=false -input=false -lockfile=readonly
pre-commit run --all-files
cd infra
terraform fmt -recursive
terraform validate
terraform test -no-color
```

For the security check alone, run `pre-commit run terraform_trivy --all-files` or `bash scripts/scan-terraform.sh` from the repository root. The script scans all of `infra`, shows advisory findings, and cleans up its temporary files. It requires no AWS credentials.

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
- [COMPATIBILITY.md](COMPATIBILITY.md)
- [PROJECT_STATUS.md](PROJECT_STATUS.md)
- [CHANGELOG.md](CHANGELOG.md)

## License

MIT. See [LICENSE](LICENSE).

## Terraform Documentation

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
