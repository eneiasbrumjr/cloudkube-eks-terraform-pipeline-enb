# CloudKube EKS Terraform Pipeline

[![Terraform](https://img.shields.io/badge/Terraform-1.11%2B-623CE4?logo=terraform)](https://developer.hashicorp.com/terraform)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Terraform configuration for provisioning a baseline AWS EKS environment with a custom VPC, managed node group, core EKS add-ons, IRSA support, VPC Flow Logs, and GitHub Actions automation.

This repository is intended as a credible starting point for an EKS foundation, not a complete platform. It favors readable Terraform, explicit inputs, and practical defaults over large abstractions.

## What This Repository Includes

- Custom VPC with public and private subnets across multiple availability zones
- Internet gateway, optional NAT gateways, and subnet tags for Kubernetes load balancers
- EKS cluster with a managed node group in private subnets, using an explicit launch template and node security group
- Private EC2, ECR API, ECR registry and STS endpoints, plus an S3 gateway endpoint for image layers
- Configurable control plane logging
- Optional EKS secrets encryption with AWS KMS
- IAM OIDC provider and IRSA for the installed EBS CSI controller
- Managed EKS add-ons:
  `vpc-cni`, `kube-proxy`, `coredns`, `aws-ebs-csi-driver`
- VPC Flow Logs to CloudWatch Logs
- Separate operator-run bootstrap for S3 remote state, its KMS key, and GitHub OIDC plan/apply roles
- GitHub Actions workflow for `fmt`, `validate`, tests with mocked providers, Trivy reports, manual plan/apply, and generated documentation
- Pre-commit, TFLint, and terraform-docs configuration for contributor workflows

## What It Does Not Include

- Automatic bootstrap execution, state migration, or account-specific EKS deployment policies
- Workload add-ons such as AWS Load Balancer Controller, Cluster Autoscaler, ExternalDNS, or Metrics Server
- Helm releases, Argo CD, Flux, or application deployment manifests
- Opinionated RBAC, Pod Security Standards, network policies, or admission controllers
- GitHub environment protections or account settings configured on the user's behalf
- Cost automation such as scheduled scale-down or autoscaler policies beyond managed node group scaling

## Current Security Posture

Implemented in code:

- Worker nodes run in private subnets
- Kubernetes API access is private by default; public access requires explicit, restricted IPv4 CIDRs
- Private API access is required for nodes; public opt-in requires restricted IPv4 CIDRs and rejects `/0` or ranges whose combined size covers the IPv4 address space
- Public and private subnets disable automatic public IPv4 assignment
- EKS secrets encryption can be enabled with a dedicated KMS key
- IRSA supplies the EBS CSI controller role; node metadata requires IMDSv2 with hop limit 1
- The launch template attaches only the custom node security group and encrypts the gp3 root volume
- Node egress permits the private API, explicit AWS endpoints, the regional S3 prefix list, and internal node/pod traffic; external HTTPS destinations are an empty opt-in list
- Control plane logs are configurable and sent to CloudWatch Logs
- VPC Flow Logs can be enabled
- SSH requires both an EC2 key pair and explicit source security group IDs; SSM is a separate opt-in

Important limitations:

- Administration of the private API requires VPC-connected routing, DNS, authorized Kubernetes credentials, and security-group rules allowing HTTPS from the administration host or network. This repository does not provision that access path.
- EKS still creates a primary security group on its control-plane interfaces, whose rules this module does not manage. It is excluded from the node launch template. Restricting the custom control-plane group does not remove permissions from that EKS-managed group. See [NETWORK_SECURITY.md](NETWORK_SECURITY.md) for the exact ownership boundary and traffic matrix.
- Interface endpoint policies retain AWS defaults; IAM must still authorize API calls. The S3 gateway policy allows only ECR layer reads and explicitly configured additional bucket reads, and affects every client of the associated private route tables.
- Internal node-to-node traffic is allowed. Workload segmentation and Route 53 Resolver DNS Firewall are separate controls.
- The repository does not create workload IAM roles beyond the EBS CSI driver role.
- The custom network ACL is permissive and should not be treated as a hardened network boundary.
- Backend blocks remain commented. The separate `bootstrap/` root defines backing resources and identity controls, but an operator must review, provision and migrate state before use. Its roles have backend access only until resource API policies are deliberately supplied.

## Terraform Layout

`infra/` defines the workload. [`bootstrap/`](bootstrap/README.md) has its own provider lockfile, tests and state; its bucket/key and identity resources are administered separately from the EKS workflow.

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
├── scripts
│   ├── check-cloud-config.py
│   ├── scan-terraform.sh
│   └── tests
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

These defaults target a new cluster. Review the [compatibility and migration notes](COMPATIBILITY.md) before changing an existing environment: replacement nodes need temporary communication with the old group, and private endpoint DNS changes can affect other VPC clients. Configure remote state and an administration access path before applying. Review [network behavior and costs](NETWORK_SECURITY.md): the default has no general internet egress, and private endpoints incur hourly charges.

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
- Public subnets retain their internet-gateway route and load-balancer discovery tags. No NAT or Elastic IP is created by default.
- Four interface services are provisioned in every private subnet/AZ, plus an S3 gateway endpoint. Use regional private ECR images; public registries and first-time pull-through cache downloads need additional reviewed connectivity.
- To allow a required external HTTPS destination, set both `enable_nat_gateway = true` and explicit `eks_external_https_cidrs`. NAT does not bypass security-group or S3 endpoint policy restrictions.
- `eks_enable_ssm` adds SSM/SSM Messages endpoints and the node IAM attachment. Extra endpoints, private API administration sources, webhook ports and S3 object-read buckets are explicit inputs. See [NETWORK_SECURITY.md](NETWORK_SECURITY.md).
- For production use, prepare remote state and identity first through the reviewed [bootstrap runbook](bootstrap/README.md) or equivalent existing resources. Then configure the commented backend in `infra/backend.tf`; [REMOTE_STATE.md](REMOTE_STATE.md) covers migration and recovery.
- Review `infra/terraform.tfvars.example` before first apply. The interface-endpoint hourly component alone is approximately USD 58.40 for four services, two AZs and 730 hours if the regional rate is USD 0.01 per endpoint ENI-hour. This excludes EKS, nodes, storage, data processing and other services; see [FINOPS_SECURITY.md](FINOPS_SECURITY.md).

## CI/CD

The workflow checks both Terraform roots without AWS credentials. Manual cloud operations remain limited to `infra/`; the bootstrap is never automatically applied.

| Trigger | Behavior |
| --- | --- |
| Pull request targeting `main`, or push to `main`, matching the workflow path filters | Format/init/validate/mock tests for `infra` and `bootstrap`, cloud-guard tests, combined advisory security report, and separate documentation artifacts |
| Manual run with `operation: validate` (default) | The same checks, without cloud authentication |
| Manual run on `main` with `operation: plan` | Checks, AWS authentication, remote-state verification, and Terraform plan |
| Manual run on `main` with `operation: apply` | Checks, AWS authentication, remote-state verification, plan, and apply through the `production` environment |

A push or pull request never starts a cloud plan or apply. Test runs explicitly use `command = plan` with mocked AWS and TLS providers; they evaluate configuration without querying an AWS account. Format failures, initialization errors, validation errors, failed tests, and cloud plan errors fail their jobs.

### Reports and generated documentation

- The Trivy configuration scan remains **advisory**: findings at medium severity or above are reported without blocking this infrastructure baseline.
- The scan uses synthetic inputs from `bootstrap/terraform.tfvars.example`. Trivy applies that file to both roots; the only shared variable currently is `aws_region`, whose example value matches the workload default. This is one explicit static scenario, not validation of every deployment override.
- Trivy runs after Terraform validation through the same script used by the local security hook. Its version is pinned, and each scan uses an empty temporary cache to select bundled checks. Parsing diagnostics, scanner execution failures, and a missing or invalid SARIF report fail the job. A successful security job does not mean there are no findings.
- Generated scan reports are uploaded as `trivy-results` artifacts. Successful push and manual scans also upload SARIF to GitHub Security; pull requests use the artifact without requiring a write-capable token. A failed scan cannot publish a partial analysis to GitHub Security.
- Validation outcomes and the security finding count appear in the workflow summary.
- Terraform documentation is generated as `terraform-documentation` for the workload and `bootstrap-terraform-documentation` for the bootstrap. The workflow does not commit or push generated changes into a branch.
- Saved Terraform plans remain in the apply runner and are not published as artifacts.

### Manual cloud operations

Before selecting `plan` or `apply` in **Actions > Terraform EKS Pipeline > Run workflow**:

1. Prepare the S3 bucket and encryption key using the separate [bootstrap](bootstrap/README.md) or reviewed existing resources, then activate the complete backend configuration in `infra/backend.tf`. Require `encrypt = true`, `use_lockfile = true`, the correct KMS key and `allowed_account_ids`; see [REMOTE_STATE.md](REMOTE_STATE.md).
2. Prepare separate AWS IAM roles for plan and apply, review their permissions and exact OIDC trust, and configure the variables listed below. Review Terraform inputs for the same account, region and state key.
3. Select `main` and the intended operation. Other branches run the local checks but skip cloud jobs.
4. Configure required reviewers and deployment branch restrictions for the `production` environment before using `apply`. Merely naming that environment in YAML does not create those protections. Its approval precedes the plan generated inside the apply job; it is not approval of that exact saved plan.

The backend remains a commented example. Cloud operations remain blocked until identity and backend configuration are supplied. Before requesting AWS credentials, the workflow checks the required account, region and two distinct role ARNs. After initialization, it checks S3 metadata, native locking, encryption, the expected account and region, a non-empty bucket/key, and the `default` workspace. These local checks do not verify bucket ownership, actual bucket/KMS policies, versioning, recovery or effective AWS permissions.

Authentication is **OpenID Connect (OIDC) only**. Configure these GitHub Actions **variables**, not access-key secrets:

| Variable | Required value |
| --- | --- |
| `AWS_ACCOUNT_ID` | Intended AWS account, exactly 12 digits |
| `AWS_REGION` | Explicit region for the backend and Terraform provider; no default fallback |
| `AWS_PLAN_ROLE_ARN` | IAM role in that account, authorized for plan and lockfile operations |
| `AWS_APPLY_ROLE_ARN` | A different IAM role in that account, authorized for reviewed infrastructure changes |

Set repository variables so both jobs can validate the role pair. Review any `production` environment overrides against the same account and role contract. The provider receives `TF_VAR_aws_region` from the selected region. The credentials action is pinned by commit and checks the assumed account. Existing `AWS_ROLE_ARN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and secret-scoped `AWS_REGION` settings are no longer consumed by these jobs.

Only manual cloud jobs request an OIDC token. The bootstrap defines the AWS OIDC provider, role trust and backend permissions; account-specific resource policies and GitHub settings still need operator review. [OIDC.md](OIDC.md) documents exact subjects, repository IDs and branch/environment conditions. No bootstrap resources have been provisioned or AWS deployment validated by this repository work.

See [TEST_RESULTS.md](TEST_RESULTS.md) for executed checks and their limits.

## Local Contributor Workflow

Install the local tools described in [CONTRIBUTING.md](CONTRIBUTING.md), including Trivy `0.76.1` and pre-commit `>= 4.4.0`.

```bash
pre-commit install
terraform -chdir=infra init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap init -backend=false -input=false -lockfile=readonly
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
pre-commit run --all-files
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra test -no-color
terraform -chdir=bootstrap fmt -check -recursive
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap test -no-color
```

For the security check alone, run `pre-commit run terraform_trivy --all-files` or `bash scripts/scan-terraform.sh` from the repository root. The script scans Terraform in both roots, excludes Git metadata and Terraform caches, shows advisory findings, and cleans up its temporary files. It requires no AWS credentials.

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
- [NETWORK_SECURITY.md](NETWORK_SECURITY.md)
- [FINOPS_SECURITY.md](FINOPS_SECURITY.md)
- [COMPATIBILITY.md](COMPATIBILITY.md)
- [REMOTE_STATE.md](REMOTE_STATE.md)
- [OIDC.md](OIDC.md)
- [Bootstrap runbook](bootstrap/README.md)
- [PROJECT_STATUS.md](PROJECT_STATUS.md)
- [CHANGELOG.md](CHANGELOG.md)

## License

MIT. See [LICENSE](LICENSE).

## Terraform Documentation

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
