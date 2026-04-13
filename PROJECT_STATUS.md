# Project Status

Last updated: 2026-04-13

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

The repository is suitable as a baseline or portfolio-quality infrastructure example, but it is not a complete production platform by itself.

What still depends on the adopting team:

- remote-state provisioning
- GitHub OIDC IAM setup in AWS
- endpoint exposure hardening
- workload add-ons and operational tooling
- RBAC, policy, and application-level security

## Recent Improvements

- Corrected Kubernetes discovery tags to use the full EKS cluster name
- Scoped the cluster control plane to private subnets only
- Tightened Terraform and provider version constraints
- Added stronger input validation and clearer example configuration
- Updated CI to prefer GitHub OIDC with access-key fallback
- Rewrote the top-level documentation to match implemented behavior

## Known Gaps

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
