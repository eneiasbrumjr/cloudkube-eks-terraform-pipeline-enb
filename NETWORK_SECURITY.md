# Network Security

Last reviewed: 2026-10-23

The default configuration uses a private Kubernetes API, an explicitly attached worker-node security group, private AWS service endpoints, and no NAT gateway. This document describes Terraform source and its limits. It does not establish the state of an existing AWS environment or successful cluster operation. See [TEST_RESULTS.md](TEST_RESULTS.md) for recorded checks and [SECURITY_AUDIT.md](SECURITY_AUDIT.md) for the findings history.

## Security-Group Ownership

The EKS module creates its custom security groups and endpoints in [network.tf](infra/modules/eks/network.tf). The [launch template](infra/modules/eks/launch_template.tf) attaches **only `aws_security_group.eks_nodes`** to managed-node interfaces. AWS documents that EKS does not add its primary cluster SG to managed nodes when a launch template specifies custom SGs. All required node connectivity must therefore be supplied explicitly. See [EKS launch-template behavior](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html).

| Group | Attachment and ownership | Boundary |
| --- | --- | --- |
| Custom control-plane SG (`eks_cluster`) | Terraform creates it and passes it as an additional cluster SG. | Supplies explicit API ingress and control-plane-to-node rules. |
| Custom node SG (`eks_nodes`) | Attached through the managed node group's launch template. | Supplies the node interfaces' configured ingress and egress rules. |
| Endpoint SG (`endpoints`) | Attached to each interface endpoint. | Accepts TCP 443 from the node SG; established response traffic is stateful. |
| EKS-created primary cluster SG | EKS still attaches this group to control-plane interfaces. This repository does not adopt or exclusively manage its rules. | **Its default outbound allowance remains an unresolved control-plane boundary.** |

Permissions from attached SGs are combined. Restricting the additional control-plane SG cannot revoke traffic allowed by the primary group. An SG reference also does not attach that SG to another interface. The launch template fixes the earlier node attachment gap, while the primary control-plane group remains a separate concern. See [SG rule behavior](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html) and [EKS SG defaults](https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html).

The pinned AWS provider **5.100.0** has no exclusive-rule adoption resource for the arbitrary SG created by EKS. Individual rule resources do not revoke existing rules they do not own. `aws_default_security_group` concerns the VPC default group, which is different. A future change must establish explicit ownership and lifecycle handling before claiming restricted primary-cluster-SG egress; this configuration does not hide an import, provisioner, or AWS CLI mutation. See the provider's [EC2 resource registrations](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/internal/service/ec2/service_package_gen.go) and [default-SG documentation](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/website/docs/r/default_security_group.html.markdown).

## Traffic Matrix

The matrix describes initiated traffic configured by the module. SGs also permit responses to allowed connections. The primary-SG limitation above still applies to control-plane outbound traffic.

| Source | Destination | Protocol / port | Purpose or condition |
| --- | --- | --- | --- |
| Node SG | Custom control-plane SG | TCP 443 | Private Kubernetes API. |
| Custom control-plane SG | Node SG | TCP 443, 10250 | HTTPS webhooks and kubelet communication. |
| Custom control-plane SG | Node SG | TCP and UDP 53 | Node-hosted DNS path. |
| Node SG | Same node SG | All protocols and ports | Internal node and pod traffic; not workload isolation. |
| Node SG | Endpoint SG | TCP 443 | Configured regional AWS APIs. |
| Node SG | Regional S3 prefix list | TCP 443 | Gateway endpoint path, limited by its policy. |
| Node SG | VPC resolver (`VPC CIDR + 2`) | TCP and UDP 53 | Documents the expected DNS path; see the limitation below. |
| Explicit administration SGs | Custom control-plane SG | TCP 443 | `eks_api_admin_security_group_ids`, empty by default. |
| Explicit SSH source SGs | Node SG | TCP 22 | Requires both `eks_ssh_key_name` and `eks_ssh_source_security_group_ids`. |
| Custom control-plane SG | Node SG | Explicit extra TCP ports | `eks_control_plane_webhook_ports`, empty by default. |
| Node SG | Explicit external IPv4 CIDRs | TCP 443 | `eks_external_https_cidrs`, empty by default; requires NAT. |

The baseline follows [EKS communication requirements](https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html). A webhook listening on another port needs that actual TCP port in `eks_control_plane_webhook_ports`. Load balancers need separate target/health-check SG rules; this webhook input does not authorize a load balancer. Controllers can also require service endpoints and IAM, such as `elasticloadbalancing` for AWS load-balancer operations. See [EKS network security guidance](https://docs.aws.amazon.com/eks/latest/best-practices/network-security.html).

**SGs do not filter AmazonProvidedDNS/Route 53 Resolver.** The resolver rules document the intended path; DNS filtering would require a separate control such as Route 53 Resolver DNS Firewall. Node self rules also do not implement Kubernetes NetworkPolicy or pod segmentation. See [AWS SG limitations](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html).

## Private AWS Service Access

Four interface services are created by default, with private DNS enabled and an endpoint interface in every configured private subnet/AZ:

| Service suffix | Intended use |
| --- | --- |
| `ec2` | EC2 APIs used by VPC CNI and EBS CSI components. |
| `ecr.api` | Private ECR API and authentication operations. |
| `ecr.dkr` | Private ECR registry traffic. |
| `sts` | Regional AWS STS, including IRSA credentials. |

The regional S3 gateway endpoint supplies the image-layer path. This set is a bounded baseline, not a complete list of application dependencies. See [private EKS requirements](https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html).

Interface endpoints retain **AWS's default full-access endpoint policy**. IAM and resource policies still authorize operations. The endpoint SG restricts the network destination; it does not restrict accounts, repositories, or API actions available to an authorized principal. This is not a data perimeter. See [endpoint access policies](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html).

### S3 Policy and Shared Route Tables

The gateway policy allows only `s3:GetObject` on the regional `arn:aws:s3:::prod-REGION-starport-layer-bucket/*` and objects in explicit `eks_s3_read_bucket_arns` buckets. Supply bucket ARNs such as `arn:aws:s3:::approved-artifacts`, without object suffixes or wildcards. This input adds object reads only; it does not grant IAM permission, listing, writes, deletes, or lock-file operations. The ARN and endpoint naming target the commercial AWS partition.

**The gateway route and policy affect every client using the associated private route tables, not only EKS nodes.** Other S3 operations are denied through this endpoint unless its policy is expanded and the caller authorized. A future private Terraform runner needs reviewed backend reads, writes, listing, and locking; adding a read-only bucket ARN is insufficient. The current GitHub-hosted CI runner is outside these VPC route tables. NAT does not bypass the more specific S3 endpoint route. Review shared clients before changing the endpoint; route changes can interrupt existing S3 connections. See [S3 gateway behavior](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html) and [ECR's S3 policy example](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html).

### Images and External Services

The default supplies no general worker-node internet path. Prepare required images in reachable private ECR repositories. Docker Hub, other public registries, package mirrors, and public application APIs are not enabled by these four endpoints. AWS also documents a NAT/internet requirement for the first pull through an ECR pull-through cache rule; do not assume that first pull works in this default. See [ECR endpoint considerations](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html).

`eks_external_https_cidrs` permits explicit IPv4 destinations on **TCP 443 only**, with `enable_nat_gateway = true`. Validation rejects `/0`, IPv6, and combined ranges covering the full IPv4 address space. NAT provides routing and translation; it does not replace the SG allowlist. Registry/CDN addresses and dependencies can change, so allowlists need maintenance and functional testing. HTTP 80 is not opened by this input. See [NAT gateway behavior](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html).

### IRSA and Optional Services

`enable_irsa` must remain true for the installed EBS CSI add-on. The STS endpoint serves the **regional** hostname; a client using `sts.amazonaws.com` does not automatically use it. Verify the resolved add-on/SDK version and other workloads' regional behavior. Use SDK configuration or the AWS-documented service-account annotation where supported. No unverified EKS add-on configuration field is injected here. See [regional STS](https://docs.aws.amazon.com/eks/latest/userguide/configure-sts-endpoint.html) and [EBS CSI IAM requirements](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html).

| Input / choice | Effect | Additional requirements |
| --- | --- | --- |
| `eks_enable_ssm = true` | Adds `ssm` and `ssmmessages` endpoints and the node's `AmazonSSMManagedInstanceCore` policy. Default is false. | Compatible running agent, operator permissions, and feature-specific destinations/policies. |
| `eks_additional_interface_endpoint_services` | Adds regional service suffixes to the endpoint set. Default is empty. | Verify regional availability, private DNS, IAM, software configuration, and recurring cost. |
| Optional `logs` | Private node/pod CloudWatch Logs path. | Agent/application and IAM still required. No Logs endpoint is created by default. |
| Optional `eks` | AWS EKS management API, such as `DescribeCluster`. | Separate from the private Kubernetes API. |
| Optional `eks-auth` / `oidc-eks` | Pod Identity API / VPC-originated OIDC discovery where needed and available. | Neither replaces regional STS for IRSA. Pod Identity is not configured by default. |

SSM patching, agent updates, scripts, and session logging need additional review. Reads from AWS-managed buckets need policy/IAM allowances; S3 output uploads require writes that `eks_s3_read_bucket_arns` cannot supply. Optional `logs` or `kms` endpoints may be needed for chosen logging/encryption features. See [Systems Manager VPC requirements](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html). EKS control-plane logging and VPC Flow Logs use AWS service delivery paths; configuring them does not provide a node/pod Logs endpoint.

## Administration and Node Settings

Private API access is mandatory even when restricted public access is opted in. Private administrators need a connected network path, an eligible source SG in `eks_api_admin_security_group_ids`, and IAM/Kubernetes authorization. No VPN, bastion, or private runner is created. `aws eks update-kubeconfig` does not establish connectivity. A Terraform runner also needs AWS API and OIDC issuer access when reading the issuer certificate. See [EKS API endpoints](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html) and [EKS interface endpoints](https://docs.aws.amazon.com/eks/latest/userguide/vpc-interface-endpoints.html).

The launch template requires IMDSv2, sets response hop limit 1, and specifies an encrypted gp3 root volume. The metadata setting limits ordinary container-network access to node credentials; it is not isolation from host-network or privileged workloads. Workload IAM and pod security remain necessary. See [IRSA and metadata access](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html). EKS selects the AL2023 AMD64 image and supplies managed bootstrap configuration. These source settings have not been verified on live instances.

## Existing-Cluster Migration and Runtime Validation

Existing node groups without a custom launch template **require replacement**. A staged blue/green migration needs more than unique names and `create_before_destroy`. See [managed-node constraints](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html).

Old nodes using the EKS-managed primary SG and new nodes using only the custom node SG do **not** automatically share the self-rule permissions. While both groups coexist, explicitly review temporary bidirectional old/new node-SG rules for required pod, service, and DNS traffic.

**Endpoint private DNS changes EC2/ECR/STS resolution for other VPC clients too**, including old nodes still using the primary EKS SG. The endpoint SG initially permits only the new custom node SG, so old nodes and other clients can lose AWS API access when these endpoints become active. Before activating endpoint private DNS or changing those paths, stage reviewed TCP 443 endpoint-ingress rules for the old node SG and each necessary client SG. Do not assume the current one-step configuration performs that transition. Validate endpoints, DNS, cross-group connectivity, and workloads, migrate/drain with disruption budgets and storage considered, then remove temporary access after old clients no longer require it.

Keep existing NAT and SSM choices explicit during the transition. Do not remove an old path before its replacement works. The S3 gateway policy affects old nodes and unrelated private-subnet clients immediately through their route tables. Review endpoints, NAT changes, route associations, IAM attachments, temporary capacity, quotas, and endpoint IP consumption in a real plan before applying.

No AWS resources were created or changed during this review. Runtime validation remains necessary for actual SG attachments, node join/readiness, DNS, ECR pulls, CNI, regional STS/IRSA, EBS volume provisioning, kubelet/webhook traffic, administration, and workload dependencies. Verify denied external destinations and S3 operations as well as allowed paths. Mocked tests and a configuration scan cannot establish these outcomes.
