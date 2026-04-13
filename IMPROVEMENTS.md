# Improvement Notes

Last updated: 2026-04-13

This file tracks the most important modernization changes that were applied during the repository review.

## Applied

- Fixed Kubernetes discovery tags to use the real cluster name instead of only `project_name`
- Scoped EKS control-plane subnets to private subnets
- Tightened Terraform and provider version constraints
- Added stronger input validation for CIDRs, scaling values, log types, and tag keys
- Raised the default CloudWatch log retention to 30 days
- Updated GitHub Actions to prefer AWS OIDC while keeping access-key fallback
- Limited plan and docs writeback jobs to same-repository pull requests
- Started tracking `.terraform.lock.hcl` for reproducible provider selection
- Rewrote README, contributing guidance, security notes, and project status docs to match implemented behavior

## Intentionally Not Added

- GitHub OIDC IAM resources in AWS
- Remote-state bootstrap resources
- Workload add-ons such as AWS Load Balancer Controller or Cluster Autoscaler
- Full platform security controls such as Pod Security Standards, RBAC policy packs, or NetworkPolicies

## Remaining Follow-Up

1. Bootstrap remote state.
2. Enforce GitHub OIDC only after AWS-side IAM is in place.
3. Decide whether the default EKS public endpoint exposure should remain convenience-oriented or become private-by-default.
4. Split any future workload add-ons into separate modules rather than expanding the base layer indiscriminately.
