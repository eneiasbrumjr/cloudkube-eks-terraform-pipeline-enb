# Project Status

Last updated: 2026-10-23

## Current scope and maturity

**Infrastructure baseline with static validation and mocked regression tests; AWS deployment and runtime behavior remain unvalidated.**

The repository defines a VPC, EKS control plane, AL2023 managed nodes, four core EKS add-ons, IRSA for EBS CSI, logging, and a private AWS service network. The node launch template attaches only the custom node SG, enforces IMDSv2 and encrypted gp3 disks, and selects a numeric template version. NAT and SSM are opt-ins. The source-defined network paths and ownership limits are documented in [NETWORK_SECURITY.md](NETWORK_SECURITY.md).

The two custom-group unrestricted-egress rules have been replaced by explicit paths. The current local scan reports zero medium-or-higher findings with unchanged Trivy 0.76.1 policies. This does not attest to runtime security: EKS still creates a separate control-plane SG whose rules the module does not manage. See [SECURITY_AUDIT.md](SECURITY_AUDIT.md) and [TEST_RESULTS.md](TEST_RESULTS.md).

Automatic GitHub Actions runs initialize both `infra` and `bootstrap` without a backend and use mocked providers plus offline cloud-guard tests. Cloud plan/apply remain limited to an explicit manual operation on main for `infra`, with separate OIDC roles and an explicit account/region. The new operator-owned bootstrap defines S3/KMS storage and GitHub trust/backend policies. Backend blocks remain commented; this work has not authenticated to AWS, provisioned resources, migrated state or performed a deployment.

## Recent completed improvements

- Repaired GitHub Actions and isolated automatic checks from manual cloud operations.
- Updated automatic actions to pinned Node24 versions and aligned local/CI Trivy behavior.
- Refreshed Kubernetes availability and selected explicit AL2023 x86_64 nodes.
- Required private API access, restricted public opt-in and disabled subnet auto public IPs.
- Attached the intended node SG through a launch template and restricted its network paths.
- Added private EC2/ECR/STS and S3 dependencies, with explicit options and cost documentation.
- Added regression coverage for resource wiring, traffic rules, endpoint options, metadata, volumes and routing.
- Documented replacement/migration behavior and the remaining EKS-managed control-plane boundary.
- Removed static-key authentication fallback and added checks for account, region, distinct OIDC roles and initialized backend settings.
- Updated the commented S3 example for native locking, documented identity/state setup and recovery, and ignored common local state, plan and backend-config files.
- Added a separate bootstrap root for versioned private S3 state, KMS, exact GitHub OIDC trust and separate plan/apply roles with backend-only default permissions.
- Added mocked bootstrap regressions and extended credential-free validation, security scanning and generated documentation to both roots.

## Prioritized follow-up

Effort is a relative engineering estimate, not a deployment authorization or schedule.

| Priority | Task | Importance | Effort | Status / acceptance evidence |
| --- | --- | --- | --- | --- |
| P1 | OIDC-only manual jobs with distinct roles and expected account/region | High | Low | Implemented in the workflow with offline regression checks; AWS trust/permissions remain external |
| P1 | Modern S3 example, backend guards and protection for local state/plan files | High | Low | Implemented; example stays inactive, with no bucket created or migration performed |
| P2 | Actionable identity, migration and recovery guidance | High | Low | Added OIDC.md and REMOTE_STATE.md; external settings still require operator review |
| P1 | Define and statically validate the remote-state and OIDC bootstrap | High | Medium | Implemented in a separate root; resource API policy inputs default to empty |
| P1 | Operator provision/migrate state, review resource policies and configure GitHub protections | Critical before deployment | Medium | Pending; requires account-specific decisions and live locking/recovery/identity checks |
| P1 | Private administration path and deployment/migration plan | Critical before deployment | Medium | Requirements documented; host/VPN/routing, IAM and RBAC not provisioned |
| P1 | Adopt and restrict the EKS-managed control-plane SG | High | Medium | Ownership boundary documented; requires an explicit state/adoption design |
| P1 | AWS integration validation in an approved test environment | High | Medium | Pending: regional versions, node join, DNS, ECR, IRSA/CSI, SG attachments and blocked egress |
| P2 | Separate VPC CNI permissions from the node role and review endpoint/IAM policies | High | Medium | Current node role still has CNI permissions; interface policies retain AWS defaults |
| P2 | Pin reviewed regional add-on versions | High | Low to medium | Current selectors use most_recent; requires compatibility evidence |
| P2 | Add workload security and required controllers in separate modules | High | High | RBAC, Pod Security Standards, NetworkPolicies and operational controllers are not supplied |
| P3 | Produce a deployment-backed portfolio case study | Medium | Medium | Describe only observed outcomes; no performance, availability or savings claims without evidence |

## Known operational limits

- Private endpoint charges are material even with NAT disabled; this is not a zero-cost lab.
- The EKS-managed control-plane SG, permissive NACL and internal node-to-node access remain documented boundaries.
- The S3 gateway policy affects every client of the private route tables, including any private CI runner.
- Moving to the custom launch template/name prefix replaces an existing managed node group. Unique names permit overlap but do not guarantee disruption-free draining.
- DNS Firewall, workload deployments, autoscaling controllers, external DNS and load-balancer controllers are separate work.
- Bootstrap definitions are available, but their provisioning/recovery are operator-owned. CI roles have no generated EKS deployment policy; external policies and the optional permissions boundary need review.

Current source: [main](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/tree/main). Hosted evidence is attached to the corresponding pull request and Actions runs; [TEST_RESULTS.md](TEST_RESULTS.md) records the local evidence and limits.
