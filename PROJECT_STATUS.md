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
- GitHub Actions workflow for validation, tests with mocked providers, security scanning, manual planning/apply, and generated documentation

## Current Maturity

**Status: infrastructure baseline with validated GitHub Actions checks; cloud deployment remains unvalidated.**

The current baseline defaults to Kubernetes 1.36 with an explicit AL2023 x86_64 node AMI, private API access, blocking endpoint input guards, and no automatic public-IP assignment in subnets. The local Trivy result fell from six findings to two remaining CRITICAL unrestricted-egress findings. See [SECURITY_AUDIT.md](SECURITY_AUDIT.md) for their disposition, [COMPATIBILITY.md](COMPATIBILITY.md) for dated support and migration notes, and [TEST_RESULTS.md](TEST_RESULTS.md) for executed checks and limits.

Automatic runs perform checks without AWS credentials. Cloud plan and apply require an explicit manual operation on `main` and an initialized S3 backend. The backend remains an unconfigured example, so cloud operations are not ready to run.

The repaired workflow completed successfully in [GitHub Actions run #12](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/actions/runs/40020683358) for [PR #5](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/pull/5). Terraform validation, the advisory security scan, and documentation generation passed; manual plan and apply jobs were skipped. Earlier failures remain in the run history. No AWS authentication, plan, apply, or deployment was executed during this repair.

What still depends on the adopting team:

- remote-state provisioning
- GitHub OIDC IAM setup in AWS
- private administration connectivity and review of effective security-group attachments and egress
- workload add-ons and operational tooling
- RBAC, policy, and application-level security

## Recent Improvements

- Refreshed Kubernetes version availability and selected an explicit AL2023 node AMI
- Made public API access an explicit opt-in with blocking IPv4 allowlist guards
- Disabled automatic public-IP assignment without removing NAT or internet-gateway routes
- Added plan-only tests with mocked AWS and TLS providers to automatic checks
- Documented the two remaining egress findings and corrected security-group output descriptions
- Updated the automatic workflow actions to Node24 releases pinned by commit
- Aligned local and GitHub Actions security scans through one Trivy script with isolated temporary caches
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

- Regional EKS/add-on availability, node readiness, and workload compatibility remain unvalidated
- Two CRITICAL unrestricted-egress findings remain; the scanner is advisory
- EKS-managed security-group rules and actual node-group attachments need explicit design and validation
- Private administration routing and ingress are not provisioned
- Existing AL2 node groups require a separate migration plan; the current fixed name and create-before-destroy behavior do not automate replacement
- The custom network ACL is permissive
- No AWS Load Balancer Controller, Metrics Server, Cluster Autoscaler, or ExternalDNS
- No remote-state bootstrap module
- No workload deployment layer

## Recommended Next Steps

1. Define and validate effective security-group ownership and required egress, addressing the two remaining CRITICAL findings.
2. Prepare private administration connectivity, durable remote state and locking, and GitHub OIDC trust in a deliberately configured environment.
3. Review the actual cluster and node state before any existing-environment upgrade, then validate regional EKS/add-on availability and workloads.
4. Add workload-level controls and add-ons in separate modules rather than growing the base layer indiscriminately.
