# Security Audit

Last reviewed: 2026-04-13

This file summarizes the repository's current security posture as implemented in code. It is intentionally factual and does not treat recommended follow-up work as already complete.

## Implemented Controls

- No hardcoded AWS credentials in tracked Terraform or workflow files
- `.gitignore` excludes Terraform state, plans, and local variable files
- GitHub Actions uses GitHub OIDC when `AWS_ROLE_ARN` is configured, with access-key fallback for compatibility
- EKS worker nodes are placed in private subnets
- EKS secrets encryption can be enabled with a dedicated KMS key
- IRSA can be enabled through an EKS OIDC provider
- EKS control plane logs can be enabled in CloudWatch Logs
- VPC Flow Logs can be enabled
- Node SSH access is disabled unless `eks_ssh_key_name` is set
- The node IAM role includes `AmazonSSMManagedInstanceCore`

## Known Security Gaps

- Public API endpoint access is enabled by default and defaults to `0.0.0.0/0`
- The repository does not provision GitHub OIDC IAM resources in AWS
- The custom network ACL is permissive and should not be considered a hardened control
- CloudWatch log groups are not KMS-encrypted by this repository
- No workload-level security controls are created:
  Pod Security Standards, NetworkPolicies, admission policies, or namespace RBAC baselines
- No secrets-management integration is included beyond EKS secrets encryption

## Recommended Actions Before Production Use

- Restrict `cluster_endpoint_public_access_cidrs` to trusted addresses or disable public endpoint access
- Provision and use an S3 backend with DynamoDB locking
- Create AWS IAM resources for GitHub OIDC and stop relying on long-lived credentials
- Add workload IAM roles and least-privilege policies for real applications
- Define cluster RBAC, Pod Security Standards, and network policies outside this base infrastructure
- Encrypt CloudWatch log groups if your compliance requirements require it

## Validation Notes

During this review:

- `terraform fmt -check -recursive` passed locally
- `terraform validate` passed locally
- `tflint`, `tfsec`, and `terraform-docs` were not available in the local shell environment

## Responsible Disclosure

Please report security issues privately to `eneiasbrumjr@gmail.com` with the subject `SECURITY`.
