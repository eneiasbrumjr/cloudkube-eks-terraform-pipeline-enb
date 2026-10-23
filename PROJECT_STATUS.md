# Project Status

Last updated: 2026-10-23

## Current scope and maturity

**Infrastructure baseline with static validation and mocked regression tests; AWS deployment and runtime behavior remain unvalidated.**

The repository defines a VPC, EKS control plane, AL2023 managed nodes, four core EKS add-ons, IRSA for EBS CSI, logging, and a private AWS service network. The node launch template attaches only the custom node SG, enforces IMDSv2 and encrypted gp3 disks, and selects a numeric template version. NAT and SSM are opt-ins. The source-defined network paths and ownership limits are documented in [NETWORK_SECURITY.md](NETWORK_SECURITY.md).

The two custom-group unrestricted-egress rules have been replaced by explicit paths. The current local scan reports zero medium-or-higher findings with unchanged Trivy 0.76.1 policies. This does not attest to runtime security: EKS still creates a separate control-plane SG whose rules the module does not manage. See [SECURITY_AUDIT.md](SECURITY_AUDIT.md) and [TEST_RESULTS.md](TEST_RESULTS.md).

Automatic GitHub Actions runs initialize without a backend and use mocked providers. Cloud plan/apply still require an explicit manual operation on main and an initialized S3 backend. The backend remains an unconfigured example. This work has not authenticated to AWS, provisioned resources or performed a deployment.

## Recent completed improvements

- Repaired GitHub Actions and isolated automatic checks from manual cloud operations.
- Updated automatic actions to pinned Node24 versions and aligned local/CI Trivy behavior.
- Refreshed Kubernetes availability and selected explicit AL2023 x86_64 nodes.
- Required private API access, restricted public opt-in and disabled subnet auto public IPs.
- Attached the intended node SG through a launch template and restricted its network paths.
- Added private EC2/ECR/STS and S3 dependencies, with explicit options and cost documentation.
- Added regression coverage for resource wiring, traffic rules, endpoint options, metadata, volumes and routing.
- Documented replacement/migration behavior and the remaining EKS-managed control-plane boundary.

## Prioritized follow-up

Effort is a relative engineering estimate, not a deployment authorization or schedule.

| Priority | Task | Importance | Effort | Status / acceptance evidence |
| --- | --- | --- | --- | --- |
| P1 | Effective node SG attachment, required private egress and regressions | Critical | Medium | Implemented; static checks and mock plans recorded in TEST_RESULTS.md |
| P1 | Durable remote state, locking/recovery and GitHub OIDC trust | Critical before deployment | Medium | Pending a separate reviewed implementation; current backend is an example |
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
- DNS Firewall, workload deployments, autoscaling controllers, external DNS, load-balancer controllers and remote-state bootstrap are separate work.

Current source: [main](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/tree/main). Hosted evidence is attached to the corresponding pull request and Actions runs; [TEST_RESULTS.md](TEST_RESULTS.md) records the local evidence and limits.
