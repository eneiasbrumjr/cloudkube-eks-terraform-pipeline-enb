# Kubernetes and EKS Compatibility

Reviewed: **2026-10-23**

This document records the repository's configuration baseline, documented EKS availability, and provider schema checks. AWS deployment, node readiness, add-on operation, and application compatibility remain unvalidated.

## Kubernetes baseline and availability

The default is **Kubernetes 1.36**, available on EKS since **2026-06-02**, with standard support ending on **2027-08-02**. It provides an established release with a useful support window. The newer 1.37 became available on EKS on 2026-10-01.

The allowlist retains versions available in either standard or extended support so that currently supported intermediate upgrade targets remain selectable:

| Kubernetes minor | Support on 2026-10-23 | End of standard support | End of extended support |
| --- | --- | --- | --- |
| 1.31 | Extended | 2025-11-26 | 2026-11-26 |
| 1.32 | Extended | 2026-03-23 | 2027-03-23 |
| 1.33 | Extended | 2026-07-29 | 2027-07-29 |
| 1.34 | Standard | 2026-12-02 | 2027-12-02 |
| 1.35 | Standard | 2027-03-27 | 2028-03-27 |
| **1.36** | **Standard; repository default** | **2027-08-02** | **2028-08-02** |
| 1.37 | Standard | 2027-12-01 | 2028-12-01 |

This is a dated availability list, not a runtime certification for every minor. Extended support carries additional charges. Versions 1.29 and 1.30 are no longer listed as available. Review the allowlist and the [official EKS release calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) before deployment or upgrades.

## Terraform and provider evidence

The configured minimum Terraform version is **1.11** for `override_during = plan` in the mock-provider tests. This also covers the cross-variable input validation introduced in 1.9. The workflow continues to use **Terraform 1.12.2**; the lockfile preserves **AWS provider 5.100.0** and **TLS provider 4.2.1**. See the [Terraform 1.11 test improvements](https://www.hashicorp.com/en/blog/terraform-1-11-ephemeral-values-managed-resources-write-only-arguments) and [provider mocking reference](https://developer.hashicorp.com/terraform/language/tests/mocking).

Inspection of the exact AWS provider release confirms:

- Cluster `version` is a string without a fixed minor-version enum and is passed to the EKS API: [provider 5.100.0 cluster implementation](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/internal/service/eks/cluster.go).
- Node-group `ami_type` uses the AWS SDK enum: [provider 5.100.0 node-group implementation](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/internal/service/eks/node_group.go).
- That provider uses EKS SDK **v1.65.1**, which already includes `AL2023_x86_64_STANDARD`: [provider dependencies](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/go.mod) and [SDK AMI enum](https://github.com/aws/aws-sdk-go-v2/blob/service/eks/v1.65.1/service/eks/types/enums.go).

These checks establish that the proposed settings are expressible with the locked provider. Successful AWS API calls and cluster operation require separate validation.

## Managed-node AMI

The managed node group explicitly uses **`AL2023_x86_64_STANDARD`**, matching the default x86 instance types `t3.medium` and `t3a.medium`. Other architectures require a corresponding AMI choice and compatible workloads.

AWS defaults new managed node groups on Kubernetes 1.30 or later to AL2023. EKS stopped publishing AL2 AMIs on **2025-11-26**; 1.32 was the final Kubernetes minor with EKS AL2 AMIs. See [optimized Amazon Linux AMIs](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html) and [AL2 deprecation](https://docs.aws.amazon.com/eks/latest/userguide/eks-ami-deprecation-faqs.html).

AL2023 requires VPC CNI **1.16.2 or later** and changes node initialization, cgroups, and instance metadata behavior. The custom launch template configures networking, metadata and storage without supplying an AMI ID or user data, so EKS still supplies the managed AL2023 bootstrap. It requires IMDSv2 with hop limit 1; ordinary pods must use workload credentials such as IRSA rather than relying on the node role. Host-network pods have a different metadata-access boundary. Workloads that depend on host configuration or node credentials need review. See [AWS AL2023 migration guidance](https://docs.aws.amazon.com/eks/latest/userguide/al2023.html).

## Add-on version selection

The four `aws_eks_addon_version` data sources retain `most_recent = true` and filter by the requested Kubernetes minor. They query the EKS API in the configured AWS region; their selected versions can change as AWS publishes releases. See the [provider data-source implementation](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/internal/service/eks/addon_version_data_source.go).

No regional add-on query or workload test was performed for this review. Before applying, inspect the resolved versions, architecture compatibility, IAM requirements, and configuration changes using the [AWS add-on compatibility guidance](https://docs.aws.amazon.com/eks/latest/userguide/addon-compat.html). EKS does not automatically update all add-ons after a control-plane upgrade; see [updating add-ons](https://docs.aws.amazon.com/eks/latest/userguide/updating-an-add-on.html).

## Existing environments

The old repository default of 1.29 is not evidence of a running cluster's current version. Inspect the actual control plane, nodes, AMIs, add-ons, and Terraform state before preparing an upgrade. EKS control-plane upgrades proceed **one minor at a time**, with workload and component compatibility reviewed at each step. See [AWS cluster upgrade guidance](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html) and the [Kubernetes version skew policy](https://kubernetes.io/releases/version-skew-policy/).

Changing an existing AL2 node group to AL2023 triggers replacement: `ami_type` is `ForceNew` in provider 5.100.0. The module now uses a generated `node_group_name_prefix` and `create_before_destroy` so replacement groups can have distinct names. Moving from the former fixed name and EKS-generated launch template to this custom template still replaces the node group. AWS does not support directly converting an existing group that lacks a custom template. Prepare a blue/green migration with sufficient capacity, workload validation and controlled draining before retiring the old group; a unique name alone does not guarantee availability. See [AWS launch-template restrictions](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html).

The network change also disables NAT and SSM by default, requires private API access and IRSA, and restricts S3 access through the new gateway policy. Applying those changes to an existing VPC before validating dependencies can interrupt running workloads. Keep explicit existing NAT/SSM settings while preparing a staged migration; review the gateway policy for every private-subnet client. SSH now needs explicit source security groups as well as a key. Read [NETWORK_SECURITY.md](NETWORK_SECURITY.md) for the migration sequence and remaining EKS-managed control-plane SG boundary.
