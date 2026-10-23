# Project Status

Last updated: 2026-10-23

## Current Scope

This repository provides a solid EKS foundation layer:

- VPC with public and private subnets
- Optional NAT gateway configuration
- EKS control plane and one managed node group
- EKS add-ons for `vpc-cni`, `kube-proxy`, `coredns`, and `aws-ebs-csi-driver`
- Optional EKS secrets encryption and IRSA
- VPC Flow Logs and configurable control-plane logging
- GitHub Actions workflow for validation, security scanning, planning, apply, and terraform-docs updates

## Current Maturity

**Status: infrastructure baseline with validated GitHub Actions checks; cloud deployment remains unvalidated.**

On 2026-10-23, actionlint accepted the repaired workflow and Terraform formatting and validation passed with the existing provider versions. The Linux runner checksums were added to the dependency lockfile. Trivy generated a SARIF report with six existing configuration findings (four critical, two high), and terraform-docs generated documentation successfully. See [TEST_RESULTS.md](TEST_RESULTS.md) for commands and limits.

Automatic runs perform checks without AWS credentials. Cloud plan and apply require an explicit manual operation on `main` and an initialized S3 backend. The backend remains an unconfigured example, so cloud operations are not ready to run.

The repaired workflow completed successfully in [GitHub Actions run #12](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/actions/runs/40020683358) for [PR #5](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/pull/5). Terraform validation, the advisory security scan, and documentation generation passed; manual plan and apply jobs were skipped. Earlier failures remain in the run history. No AWS authentication, plan, apply, or deployment was executed during this repair.

What still depends on the adopting team:

- remote-state provisioning
- GitHub OIDC IAM setup in AWS
- endpoint exposure hardening
- workload add-ons and operational tooling
- RBAC, policy, and application-level security

## Recent Improvements

- Repaired workflow syntax and separated automatic validation from manual cloud operations
- Added Linux provider checksums without upgrading providers
- Replaced the incompatible tfsec CI parser with a pinned Trivy configuration scan
- Replaced automatic branch writes with run summaries and documentation artifacts

- Corrected Kubernetes discovery tags to use the full EKS cluster name
- Scoped the cluster control plane to private subnets only
- Tightened Terraform and provider version constraints
- Added stronger input validation and clearer example configuration
- Updated CI to prefer GitHub OIDC with access-key fallback
- Rewrote the top-level documentation to match implemented behavior

## Known Gaps

- Kubernetes version compatibility still requires review before deployment
- Security scan findings remain advisory and require contextual review

- Public endpoint access remains enabled by default for convenience
- The custom network ACL is permissive
- No AWS Load Balancer Controller, Metrics Server, Cluster Autoscaler, or ExternalDNS
- No remote-state bootstrap module
- No workload deployment layer

## Recommended Next Steps

1. Provision remote state with S3 and DynamoDB.
2. Create AWS IAM resources for GitHub OIDC and remove long-lived CI secrets.
3. Restrict or disable public EKS API access for non-development environments.
4. Add workload-level controls and add-ons in separate modules rather than growing the base layer indiscriminately.
