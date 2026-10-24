# Improvement Notes

Last updated: 2026-10-23

This file tracks the most important modernization changes that were applied during the repository review.

## Applied

- Fixed Kubernetes discovery tags to use the real cluster name instead of only `project_name`
- Scoped EKS control-plane subnets to private subnets
- Tightened Terraform and provider version constraints
- Added stronger input validation for CIDRs, scaling values, log types, and tag keys
- Raised the default CloudWatch log retention to 30 days
- Required AWS OIDC for manual cloud jobs, with separate plan/apply roles and explicit account/region checks
- Isolated automatic checks from manual main-only cloud operations and removed automatic documentation writeback
- Started tracking `.terraform.lock.hcl` for reproducible provider selection
- Updated the inactive S3 backend example for native lockfiles and added state/plan/backend-config ignore patterns
- Documented operator-owned remote state, OIDC trust, migration and recovery without provisioning AWS resources
- Added an independent, mocked-tested bootstrap for S3/KMS state and GitHub roles, with exact trust, separate state keys and scoped backend permissions
- Extended credential-free CI and shared scanning to both Terraform roots, preserving manual EKS operation gates
- Rewrote README, contributing guidance, security notes, and project status docs to match implemented behavior

## Intentionally Not Added

- Automatic AWS execution or state migration for the supplied bootstrap definitions
- Complete account-specific resource API policies or a generated permissions boundary
- Workload add-ons such as AWS Load Balancer Controller or Cluster Autoscaler
- Full platform security controls such as Pod Security Standards, RBAC policy packs, or NetworkPolicies

## Remaining Follow-Up

1. Have the operator review and execute the supplied bootstrap, migrate its own state deliberately, and verify locking, encryption and recovery in an approved environment.
2. Review the exact OIDC settings and customer-managed resource API policies, then configure GitHub variables and `production` protections. Default bootstrap roles have backend-only access; the workflow requires OIDC and has no static-key fallback.
3. Complete private administration connectivity and the remaining EKS-managed control-plane SG ownership design; the API is now private by default and managed nodes use an explicit restricted SG.
4. Split any future workload add-ons into separate modules rather than expanding the base layer indiscriminately.

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for the current prioritized backlog and [NETWORK_SECURITY.md](NETWORK_SECURITY.md) for the effective node-network design.
