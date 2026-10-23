# Security Audit

Last reviewed: 2026-10-23

This review covers the six findings in the repository's Trivy configuration-scan baseline and the corresponding Terraform changes. It describes source configuration and static validation; it does not establish the state of a deployed AWS account, successful cluster operation, or production readiness.

## Default Configuration Changes

- The Kubernetes API endpoint is private by default: `cluster_endpoint_private_access = true` and `cluster_endpoint_public_access = false`.
- `cluster_endpoint_public_access_cidrs` defaults to an empty list. Public access requires an explicit opt-in and a non-empty allowlist.
- Blocking input validation rejects both endpoint modes being disabled, public access without an allowlist, invalid or IPv6 allowlist entries, and IPv4 `/0` entries. Empty allowlists remain valid when public access is disabled. These are deployment input guards; the existing Terraform `check` blocks alone are not enforcement because failed checks produce warnings and continue the operation. See [Terraform validation behavior][terraform-validation].
- Public subnets no longer assign public IPv4 addresses to instances automatically. Their internet-gateway routes and load-balancer discovery tags remain; managed worker nodes continue to use private subnets.
- NAT gateways and private-subnet NAT routes remain enabled by default. Private API access does not replace the outbound access required by nodes and workloads.

### Administration of the Private API

With public access disabled, `kubectl` must run from the VPC or a connected network, with an allowed security-group path to TCP 443 and appropriate IAM/Kubernetes authorization. Running `aws eks update-kubeconfig` only configures a client; it does not create that network path. The repository does not provision a VPN, administration host, or private runner for this purpose. See [EKS endpoint access][eks-endpoint].

For an explicitly chosen public endpoint, use only the administrator's or runner's trusted public IPv4 CIDRs and keep private access enabled for nodes. A restricted public endpoint still represents public access: the bundled `AWS-0040` rule flags public mode, and `AWS-0041` also evaluates whether allowlisted CIDRs are public. A public `/32` can therefore retain findings even though it substantially narrows the reachable sources. The default-configuration scan does not establish the safety of every deployment override.

## Trivy Findings: Baseline and Observed Result

The scanner is pinned to **Trivy 0.76.1**, uses its bundled checks with a fresh temporary cache, and reports MEDIUM, HIGH, and CRITICAL findings. Findings remain advisory; scanner failures, Terraform parsing errors, unreadable reports, and a missing SARIF 2.1.0 run block the check. No ignore rule or finding suppression was added for this change.

The earlier measured baseline contained **6 findings: 4 CRITICAL and 2 HIGH**. A fresh local scan through the shared script after these changes reported **2 remaining CRITICAL findings**, both `AWS-0104`. It produced a SARIF 2.1.0 report and returned success in advisory mode; no ignore rules or Trivy policy changes were used.

| Rule | Severity | Source configuration | Earlier measured count | Observed count after this change | Disposition |
| --- | --- | --- | ---: | ---: | --- |
| [AWS-0040][trivy-0040] | CRITICAL | EKS public endpoint enabled | 1 | 0 | Public endpoint disabled by default; explicit opt-in remains available. |
| [AWS-0041][trivy-0041] | CRITICAL | Public endpoint allowed `0.0.0.0/0` | 1 | 0 | Empty default allowlist and blocking IPv4 allowlist validation. |
| [AWS-0104][trivy-0104] | CRITICAL | `cluster_egress` and `nodes_egress` allow all destinations | 2 | 2 | Remain visible pending a review of effective security-group attachments and required traffic. |
| [AWS-0164][trivy-0164] | HIGH | Two public subnets automatically assign public IPs | 2 | 0 | Automatic public-IP assignment disabled. |
| **Total** | | | **6** | **2** | Observed in the local static scan; remaining egress findings stay visible. |

The rule links are pinned to `trivy-checks` commit `ac85645895ed`, the dependency used by [Trivy 0.76.1][trivy-dependency]. The `AWS-0104` implementation tests unrestricted destination CIDRs independently of the port range. Replacing all protocols with TCP 443 to `0.0.0.0/0` would therefore retain that finding. Changing destination notation or suppressing the rule would not establish a restricted egress policy.

## Remaining Egress Findings and Security-Group Attachments

The two explicit outbound rules in `infra/modules/eks/main.tf` permit all protocols to `0.0.0.0/0`. They have not been removed or narrowed in this change.

The effective network model needs more work than editing these two rules:

| Security group | Relationship established by this repository |
| --- | --- |
| `aws_security_group.eks_cluster` | Passed to `aws_eks_cluster.main.vpc_config.security_group_ids` as an additional control-plane security group. |
| `aws_security_group.eks_nodes` | Not attached to managed-node interfaces through a custom launch template. It is referenced as a source security group for optional SSH access and by other rules. Those references do not attach it to nodes. |
| EKS-created cluster security group | Created by EKS and normally associated with the cluster interfaces and managed nodes. Its rules are not explicitly managed by this Terraform configuration. |

AWS documents that the automatically created cluster security group allows outbound traffic by default, and that additional cluster security groups are not automatically attached to node groups. Rules from multiple groups are combined. Restricting an additional group does not override traffic permitted by another attached group. Consequently, a lower count for the two Terraform rules alone would not demonstrate effective node-egress restriction. See [EKS security-group requirements][eks-security-groups] and [security-group rule behavior][vpc-security-groups].

A follow-up should first choose and implement ownership of the actual node and cluster security groups, then define traffic by service and workload. A custom node launch template changes EKS security-group attachment behavior and requires complete connectivity rules; introducing one is a separate functional change, not a scanner-only edit. See [custom security groups for managed nodes][eks-launch-templates].

Required traffic includes control-plane/node communication, DNS and inter-node traffic, container image pulls, and the AWS APIs used by the cluster and workloads. Preserve the required EKS ports and the application's additional destinations. Do not replace all node egress with only the VPC CIDR: NAT does not change the destination address seen by the originating node's outbound security-group rule.

## Public Subnets and Outbound Connectivity

`map_public_ip_on_launch = false` reduces accidental public addressing of future EC2 launches. It does not convert a public subnet into a private subnet: the route table still routes to the internet gateway. The current node group is already placed in private subnets, so it does not depend on this public-subnet setting. See [subnet addressing attributes][subnet-addressing] and [EKS VPC requirements][eks-network].

The public NAT gateway uses an explicitly allocated Elastic IP and remains in a public subnet. Internet-facing load balancers have their own public addressing and route requests to targets using private IPs. Disabling automatic instance addressing preserves those architectural roles. See [NAT gateways][nat-gateways] and [load-balancer addressing][load-balancers].

**Keep NAT enabled unless an alternative outbound design is implemented and validated.** A private Kubernetes API endpoint alone does not provide access to ECR, S3, STS, EC2, Systems Manager, other AWS APIs, or external registries and application services. Removing internet egress requires the relevant VPC endpoints, routing, DNS, endpoint policies, image availability, and workload-specific connectivity. The repository does not provision that complete replacement. See [EKS clusters with limited internet access][eks-private-clusters].

## Other Controls and Remaining Work

Existing configuration places nodes in private subnets, supports KMS encryption of Kubernetes secrets and IRSA, and can enable control-plane logs and VPC Flow Logs. SSH access is optional. The node role includes the Systems Manager managed policy; that policy alone does not establish an operational administration path.

Before a real deployment, also review remote state and locking, GitHub OIDC trust and deployment permissions, workload IAM and RBAC, Pod Security Standards, network policies, admission controls, and secrets handling. The repository does not provision the GitHub OIDC IAM resources or a workload security baseline. CloudWatch log-group encryption and the permissive network ACL remain outside this hardening change. These items were not comprehensively audited here.

## Validation Record

- Historical Trivy baseline: 6 findings at MEDIUM or above, as detailed in the table.
- Fresh local scan through the shared Trivy script: SARIF 2.1.0, **2 CRITICAL findings**, both `AWS-0104`; exit code 0 reflects advisory mode.
- `actionlint` passed for the workflow.
- Formatting, Terraform validation, and mocked-provider test outcomes are recorded separately in [TEST_RESULTS.md](TEST_RESULTS.md). This audit does not infer those outcomes from the scanner result.
- **TFLint was not run for this hardening review.**
- No AWS deployment, live security-group inspection, node bootstrap, image-pull, workload, or private-endpoint connectivity test was performed in this review.

A passing advisory scan is not approval of the remaining findings or proof of runtime security.

## Responsible Disclosure

Please report security issues privately to `eneiasbrumjr@gmail.com` with the subject `SECURITY`.

[terraform-validation]: https://developer.hashicorp.com/terraform/language/validate
[eks-endpoint]: https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html
[eks-security-groups]: https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
[vpc-security-groups]: https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html
[eks-launch-templates]: https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html
[subnet-addressing]: https://docs.aws.amazon.com/vpc/latest/userguide/subnet-public-ip.html
[eks-network]: https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html
[nat-gateways]: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
[load-balancers]: https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html
[eks-private-clusters]: https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html
[trivy-dependency]: https://github.com/aquasecurity/trivy/blob/v0.76.1/go.mod
[trivy-0040]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/eks/no_public_cluster_access.rego
[trivy-0041]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/eks/no_public_cluster_access_to_cidr.rego
[trivy-0104]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/ec2/no_public_egress_sgr.rego
[trivy-0164]: https://github.com/aquasecurity/trivy-checks/blob/ac85645895ed/checks/cloud/aws/ec2/no_public_ip_subnet.rego
