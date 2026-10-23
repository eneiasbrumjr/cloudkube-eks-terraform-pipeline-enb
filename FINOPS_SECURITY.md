# FinOps and Security Trade-offs

Last reviewed: 2026-10-23

The current default replaces general worker-node internet egress with explicit private AWS paths. It creates four interface endpoint services across the private subnets, adds an S3 gateway endpoint, and disables NAT by default. This is a network design choice with a recurring cost, not a claim that it is the cheapest EKS environment. No AWS resources were created during this review; the figures below are planning examples, not an account bill or complete deployment estimate.

See [NETWORK_SECURITY.md](NETWORK_SECURITY.md) for supported traffic and the unresolved EKS-managed control-plane SG boundary. Static evidence in [TEST_RESULTS.md](TEST_RESULTS.md) does not prove application readiness.

## Endpoint Cost Model

Interface endpoints incur endpoint/AZ-hour and data-processing charges. For a **conditional example** using a regional rate of **$0.01 per endpoint/AZ-hour**, two private AZs, and 730 hours:

`4 services × 2 AZs × 730 hours × $0.01 = $58.40/month`

This is the hourly component for `ec2`, `ecr.api`, `ecr.dkr`, and `sts` only. Verify the selected region/service's current rates before budgeting; see [AWS PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/).

| Endpoint choice | Endpoint interfaces across 2 AZs | Illustrative monthly hourly charge |
| --- | ---: | ---: |
| Four default services | 8 | $58.40 |
| SSM opt-in: two additional services (`ssm`, `ssmmessages`) | +4 | +$29.20 |
| Defaults plus SSM | 12 | $87.60 |
| Each additional interface service | +2 | +$14.60 |
| S3 gateway endpoint | No interface endpoint | No additional gateway-endpoint charge |

All rows use the same conditional rate. They exclude processing, cross-AZ transfer where applicable, EKS, EC2, EBS, KMS, logs, load balancers, optional NAT, taxes, and other services. An unused provisioned interface endpoint still incurs its hourly charge. S3 gateway endpoints have no additional endpoint charge; normal S3 storage/request charges depend on use. See [S3 gateway endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html).

The implementation places each interface service in every configured private subnet/AZ. Adding an AZ or service increases recurring cost. Reducing that footprint changes availability or traffic paths and should be an explicit architecture decision. There is no universal lowest-cost topology.

## NAT Is an Additional Explicit Choice

`enable_nat_gateway = false` is now the default because specific endpoint paths are configured. It still requires compatible images, SDK endpoints, policies, and application dependencies. This is not a general instruction to remove NAT from an existing cluster.

For approved external HTTPS destinations, configure both `eks_external_https_cidrs` and NAT. NAT hourly, processing, and potentially transfer/public-IPv4 charges are **additional to the private endpoints**, which remain provisioned. No endpoint is automatically removed when NAT is enabled. Review [VPC pricing](https://aws.amazon.com/vpc/pricing/) and [NAT architecture](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html).

The SG allowlist restricts destinations; NAT itself does not. A single NAT gateway reduces gateway count but couples outbound access from other AZs to its AZ and can add cross-AZ traffic. Its acceptability depends on availability requirements. Preserve an existing NAT path until its replacement and workloads are verified.

Prepare private ECR images before a restricted cluster depends on them. The first pull through an ECR pull-through cache rule can require internet/NAT access even with endpoints. Public registries and package repositories have additional dependencies. Mirroring approved artifacts and reviewing those dependencies makes connectivity and cost assumptions clearer. See [ECR endpoint considerations](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html).

## Choices to Review Together

| Choice | Cost consideration | Security / functional consideration |
| --- | --- | --- |
| Optional SSM | Adds two services in each private AZ; some features also need Logs/KMS endpoints or storage. | Adds the node IAM policy. Verify the agent and operator permissions; agent-initiated sessions do not need SSH ingress. |
| Additional interface services | Each unique service adds endpoint/AZ-hours and processing. | A service suffix supplies a path, not software, IAM authorization, or a restricted endpoint policy. |
| S3 gateway policy | No gateway endpoint hourly charge; normal service charges remain. | Default allows ECR object reads and explicit extra read buckets only. All associated private-route-table clients are affected. |
| CloudWatch Logs | Ingestion, retention, and an optional node/pod `logs` endpoint are separate costs. | No `logs` endpoint by default. Agents and permissions remain necessary; EKS/Flow Log delivery does not supply that path. |
| Spot or smaller groups | Estimate potential compute savings for the actual workload. | Account for interruptions, capacity, disruption budgets, storage, and availability. No blanket discount is assumed. |
| Node-group replacement | Blue/green migration can temporarily run both groups. | Budget overlap and quotas so the old group remains until new nodes and workloads are verified. |
| Log retention | Retention affects stored volume. | Set from investigation and policy needs; avoid unmeasured savings targets. |

SSM patching, updates, and logging need more than its two endpoints. Reading AWS-managed buckets requires gateway-policy and IAM allowances. S3 uploads require write permissions and an expanded policy. `eks_s3_read_bucket_arns` adds only `GetObject`; it cannot enable session-log writes or Terraform backend state operations. NAT does not bypass the S3 gateway route. See [Systems Manager private connectivity](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html).

## Build a Deployment-Specific Budget

Use the selected region, Kubernetes version/support tier, actual instance types and node counts, disks, endpoints/AZs, traffic, log volumes, and migration overlap in the [AWS Pricing Calculator](https://calculator.aws/). Check [EKS pricing](https://aws.amazon.com/eks/pricing/) for the chosen version; historical control-plane figures are not fixed universal monthly prices.

Node-group minimum, desired, and maximum sizes are configuration bounds. The repository does not deploy Kubernetes Cluster Autoscaler, so those settings alone do not add pod-demand-driven scaling. Savings commitments, scheduled scaling, budgets, and billing alerts need separate design or account configuration; none was purchased or created during this review.

For an existing environment, inspect the real plan before accepting a savings projection. Replacement nodes need temporary cross-group communication with old nodes. Endpoint private DNS also changes service resolution for other VPC clients; provide reviewed endpoint-SG access before that transition. New endpoint ENIs, IAM default changes, NAT removal, and S3 route/policy changes can disrupt old nodes or unrelated clients. Keep NAT/SSM choices explicit during migration, and budget capacity until the old path can safely be retired.

A private Terraform runner requires backend policy supporting its actual reads, writes, and locking; the read-only S3 baseline is insufficient. The current GitHub-hosted CI runner is outside these private route tables.

## Evidence and Remaining Security Work

The configuration improves node SG attachment and makes outbound destinations explicit. Limitations remain: the EKS-managed primary control-plane SG is not exclusively managed, interface endpoint policies remain full access, node self-traffic is allowed, and SGs cannot filter AmazonProvidedDNS. Neither a cost calculation nor zero static findings establishes a data perimeter, workload isolation, or successful operation.

Review [SECURITY_AUDIT.md](SECURITY_AUDIT.md) and current test results before deployment. Live checks still need to cover node readiness, images, CNI, regional STS/IRSA, EBS CSI, DNS, administration, webhook/health paths, and allowed/denied destinations. This work has not exercised those paths or incurred AWS deployment charges.
