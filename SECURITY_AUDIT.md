# Security Audit

Last reviewed: 2026-10-23

This review follows the repository's six-finding Trivy baseline, endpoint/node-network hardening, and the separate state/identity bootstrap. It covers source configuration and recorded static checks. It does not establish a deployed account's security state, successful cluster operation, or production readiness.

## State and Identity Bootstrap

The independent `bootstrap/` root defines private/versioned S3 state, a rotating KMS key, explicit HTTPS/KMS upload policies, and GitHub OIDC roles. Workload and bootstrap state/lock keys are distinct. Plan can read workload state; apply can read/write it; both can operate its native S3 lock. The roles are denied bootstrap object access, state deletion, version deletion and administration of the named backend/CI identity resources.

Trust conditions combine exact audience/subject, immutable repository/owner IDs and `main`, with `production` required for apply. The provider's create/reuse mode and legacy/immutable subject format require explicit operator choices. Existing-provider data checks verify issuer and audience. External resource-policy attachments depend on the protection policies being installed first.

KMS permissions require the specific key, regional S3 and workload state/lock encryption contexts. S3 Bucket Keys remain disabled to preserve those object contexts. The bucket rejects absent or different SSE-KMS/key headers; recovery uploads must use the same explicit settings. The key policy delegates IAM authorization within the configured account; account administrators retain custody.

These definitions do not supply a complete EKS API policy or a permissions boundary. Policy ARN validation cannot certify policy contents, and targeted denies are not a universal escalation boundary for arbitrary external policies. Bootstrap roles start with backend-only access. Operator provisioning, GitHub protections, effective IAM evaluation, live locking/recovery, audit logging and deployment remain unverified. See [bootstrap/README.md](bootstrap/README.md), [OIDC.md](OIDC.md) and [REMOTE_STATE.md](REMOTE_STATE.md).

## Current Configuration Changes

- The managed node group's launch template attaches **only the custom node SG**. This addresses the earlier gap where that SG existed but was not attached to managed-node interfaces.
- The two explicit world-egress rules are replaced with SG, prefix-list, resolver, and optional explicit destination rules. The complete traffic matrix is in [NETWORK_SECURITY.md](NETWORK_SECURITY.md).
- Four private interface services (`ec2`, `ecr.api`, `ecr.dkr`, `sts`) and a regional S3 gateway endpoint supply the baseline AWS paths. NAT now defaults to false; explicit external HTTPS CIDRs require NAT.
- Interface endpoints retain AWS's default full-access endpoint policy. IAM remains required; these endpoints do not establish an account or resource data perimeter.
- The S3 gateway policy permits `s3:GetObject` on the regional ECR layer bucket and optional explicit read buckets. It affects **all clients of the associated private route tables**. Private-runner state writes, SSM output uploads, listing, and other operations need a separately reviewed policy and authorization. The read-bucket input does not grant IAM or writes.
- Private API access is mandatory. Public access remains an explicit option with restricted IPv4 CIDRs and private access still enabled. Guards reject an empty public allowlist, `/0`, IPv6, and ranges covering the full IPv4 address space.
- Public subnets retain `map_public_ip_on_launch = false`. Their internet-gateway routes and load-balancer discovery tags remain; automatic addressing and public routing are different settings.
- The launch template requires IMDSv2 with hop limit 1 and encrypted gp3 storage. IRSA must remain enabled for the installed EBS CSI add-on. SSM is opt-in, including its endpoints and node IAM policy. SSH requires both a key and explicit source SGs.

These are Terraform configuration changes. Live attachments, image availability, agent behavior, DNS, and connectivity still require verification. See the [AWS private EKS requirements](https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html).

## Trivy: Measured History and Current Result

The scanner remains pinned to **Trivy 0.76.1**, with its bundled checks, a fresh temporary cache, and MEDIUM/HIGH/CRITICAL reporting. Findings remain advisory. Operational failures, Terraform parsing diagnostics, unreadable reports, and missing SARIF 2.1.0 runs block the check. No finding ignore, suppression, or scanner-policy change was added for this remediation.

The original measured baseline contained **6 findings: 4 CRITICAL and 2 HIGH**. The earlier endpoint/public-subnet hardening reduced that to **2 CRITICAL `AWS-0104` findings**. A fresh local run of the shared scanner on the current configuration completed successfully and produced SARIF with **0 findings at MEDIUM or above**. This is an observed static result, not a live network assessment. See [TEST_RESULTS.md](TEST_RESULTS.md) for the current evidence record.

The current scan includes both roots and supplies synthetic `bootstrap/terraform.tfvars.example` inputs. The flag applies across roots; only `aws_region` is currently shared, with the same value as the workload default. The final scan reports no missing-required-input warnings. This scenario does not establish coverage of every account value, custom policy or deployment override.

| Rule | Severity | Original measured count | After earlier endpoint hardening | Current observed count | Source change |
| --- | --- | ---: | ---: | ---: | --- |
| [AWS-0040][trivy-0040] | CRITICAL | 1 | 0 | 0 | Public API remains disabled by default. |
| [AWS-0041][trivy-0041] | CRITICAL | 1 | 0 | 0 | Empty default public allowlist; blocking IPv4 guards. |
| [AWS-0104][trivy-0104] | CRITICAL | 2 | 2 | 0 | Explicit world-egress rules replaced; node SG attached through the launch template. |
| [AWS-0164][trivy-0164] | HIGH | 2 | 0 | 0 | Automatic public-subnet IP assignment remains disabled. |
| **Total** | | **6** | **2** | **0** | **Measured by the configured static scan; limitations remain below.** |

Rule links are pinned to `trivy-checks` commit `ac85645895ed`, used by [Trivy 0.76.1][trivy-dependency]. `AWS-0104` evaluates unrestricted destination CIDRs independently of ports. TCP 443 to all IPv4 addresses, or splitting unrestricted access into multiple ranges, would not provide the intended destination restriction. This change does neither.

Optional public API access can still trigger `AWS-0040`; `AWS-0041` also evaluates whether allowlisted CIDRs are public, so a public `/32` can retain a finding. The example-input scan does not evaluate every deployment override. **Zero findings does not mean the EKS-managed primary SG has been restricted or that runtime security has been validated.**

## Residual Control-Plane SG Boundary

The custom control-plane SG is an **additional** group. The EKS-created primary cluster SG still attaches to control-plane interfaces, and its outbound rules are not exclusively owned by this Terraform configuration. AWS documents its default world-egress rule. Permissions are additive; narrower rules in the additional SG cannot revoke that allowance. See [EKS SG defaults](https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html) and [SG aggregation](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html).

The launch template changes this relationship on worker nodes: specifying custom SGs prevents EKS from also attaching the primary SG to those nodes. The custom node SG supplies a real attachment boundary, and its ingress rules constrain traffic arriving at nodes. This does **not** establish restricted outbound access for the whole control plane. See [managed-node custom SG behavior](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html).

The pinned AWS provider 5.100.0 has no exclusive-rule adoption resource for this arbitrary EKS-created SG. Its `aws_default_security_group` resource concerns the VPC default SG. Managing the primary cluster group requires a separately reviewed ownership and lifecycle approach; no live rule revocation was attempted. Provider evidence: [EC2 resource registrations](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/internal/service/ec2/service_package_gen.go), [default SG resource](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/website/docs/r/default_security_group.html.markdown).

## Functional and Security Limits

| Area | Remaining requirement or limit |
| --- | --- |
| Workload isolation | Node self-traffic is allowed. NetworkPolicy, pod security, admission controls, RBAC, and workload IAM remain separate. |
| DNS | SGs do not filter AmazonProvidedDNS. No Route 53 Resolver DNS Firewall is provisioned. |
| Images / external services | Default endpoints do not provide general public registry access. Verify private ECR images and first-pull behavior; explicit external HTTPS needs maintained CIDRs and NAT. |
| IRSA / metadata | Verify regional STS use by resolved add-ons and workloads. Hop limit 1 does not isolate host-network or privileged workloads from node credentials. |
| S3 / shared clients | Read-only gateway policy can block unrelated private-subnet clients. Backend state, patching, scripts, and logging require explicit action/destination review. NAT does not bypass the gateway route. |
| Endpoint private DNS | EC2/ECR/STS names resolve to endpoint interfaces for other VPC clients too. The default endpoint SG permits only the new node SG. Existing clients need reviewed access before activating that path. |
| Administration / logs | SSM, SSH, and private API administration require explicit configuration. Node/pod CloudWatch logging needs an optional `logs` endpoint and suitable software/IAM. |
| Migration | Existing groups without a custom launch template require replacement. Old/new node SGs need reviewed temporary cross-group rules; old clients also need endpoint ingress before the DNS transition. Lifecycle settings alone do not guarantee availability. |
| Other infrastructure | Bootstrap source/trust/backend policies have static coverage; live state/locking and deployment permissions remain unverified. Log-group encryption and the permissive network ACL remain separate work. |

The [network migration notes](NETWORK_SECURITY.md#existing-cluster-migration-and-runtime-validation) describe endpoint, old/new node, S3, NAT, and SSM dependencies. [FINOPS_SECURITY.md](FINOPS_SECURITY.md) covers endpoint charges and temporary migration capacity.

## Validation Record

- Historical scans: **6 findings**, then **2 `AWS-0104` CRITICAL findings** after the earlier hardening.
- Current shared Trivy scan: successful execution, SARIF 2.1.0, **0 findings at MEDIUM or above**; no scanner-policy changes or suppression.
- Backend-disabled offline initialization with the read-only dependency lockfile: passed.
- Terraform validation: passed in a sanitized environment.
- Terraform formatting, 32 workload mock tests, 26 bootstrap mock tests, 16 offline guard tests, workflow lint and isolated documentation generation passed. Commands and limits are recorded in the current entry of [TEST_RESULTS.md](TEST_RESULTS.md); the full pre-commit/TFLint suite was not rerun.
- No AWS deployment, live SG inspection, node join, private image pull, IRSA call, EBS provisioning, SSM session, workload, or endpoint-connectivity test was performed.
- Existing resources need a real plan review and staged migration before any authorized apply. No paid AWS resources were created during this work.

A passing advisory scan does not approve infrastructure or demonstrate runtime security.

## Responsible Disclosure

Please report security issues privately to `eneiasbrumjr@gmail.com` with the subject `SECURITY`.

[trivy-dependency]: https://github.com/aquasecurity/trivy/blob/v0.76.1/go.mod
[trivy-0040]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/eks/no_public_cluster_access.rego
[trivy-0041]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/eks/no_public_cluster_access_to_cidr.rego
[trivy-0104]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/ec2/no_public_egress_sgr.rego
[trivy-0164]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/ec2/no_public_ip_subnet.rego
