# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning where practical.

## [Unreleased]

### Effective node egress and private service paths - 2026-10-23

- Attached only the custom node security group through an explicit launch template; removed unrestricted egress from both custom groups and narrowed control-plane-to-node ports.
- Added private EC2, ECR API, ECR registry and regional STS endpoints, plus an S3 gateway policy limited to ECR layer reads and explicit additional object-read buckets.
- Added opt-ins for SSM, additional interface services, private API administration sources, specific webhook ports, SSH source groups and external HTTPS destinations.
- Enforced IMDSv2 with hop limit 1, encrypted gp3 root volumes and propagated instance/volume tags. Selected a numeric launch-template version and a unique managed-node-group name prefix.
- Made node creation wait for the required endpoints, network rules and IAM attachments; made the EBS CSI add-on wait for its IAM policy attachment.
- Expanded mocked regression coverage for actual resource wiring, traffic paths, optional resources, no-NAT/per-AZ routing and invalid combinations.
- Documented the unchanged EKS-managed control-plane SG boundary, private-endpoint costs and existing-environment migration requirements.
- Breaking defaults: NAT and SSM are off; private API access and IRSA are required; SSH needs explicit source groups. An existing node group is replaced when adopting the custom template/name prefix. The S3 endpoint policy affects all clients of the private route tables.
- Preserved Terraform/provider versions, lockfile, scanner policies and manual AWS-operation gates. No cloud deployment was performed.

### EKS compatibility and network defaults - 2026-10-23

- Set the new-cluster Kubernetes default to 1.36 and explicitly selected the AL2023 x86_64 managed-node AMI without upgrading provider versions.
- Refreshed the dated version allowlist to 1.31 through 1.37, distinguishing standard support from extended support in `COMPATIBILITY.md`.
- Disabled public API access by default and replaced advisory endpoint checks with blocking root input validations. Public access requires explicit IPv4 CIDRs; `/0`, IPv6, malformed CIDRs, and configurations with no endpoint access are rejected.
- Disabled automatic public-IP assignment in public subnets and made the private-subnet setting explicit, preserving NAT and internet-gateway routing.
- Corrected descriptions of the custom security groups and documented the remaining unrestricted-egress findings and EKS-managed group behavior.
- Added plan-only tests with mocked providers to local checks and CI.
- Raised the minimum Terraform requirement to 1.11 for plan-time provider mocks and cross-variable validation; the workflow remains on 1.12.2.
- Documented breaking defaults: existing clusters need a reviewed upgrade, AL2 node-group replacement, and administration connectivity plan before applying this configuration.

### Tooling maintenance - 2026-10-23

- Updated checkout, Terraform setup, artifact upload, and SARIF upload actions to Node24 releases pinned by commit.
- Replaced the local tfsec hook with the same Trivy script used by GitHub Actions, preserving the other hooks.
- Required Trivy 0.76.1 and an empty temporary cache for consistent bundled checks; retained advisory findings and blocking operational, parsing, and report errors.
- Required pre-commit 4.4 or newer for the local hook's current language identifier.
- Prevented failed scans from publishing partial analyses to GitHub Security.
- Updated contributor setup and local validation commands without changing Terraform or provider versions.

### Workflow repair - 2026-10-23

- Corrected unsupported secret references in workflow conditions.
- Restricted cloud plan and apply to explicit manual runs on `main`; automatic runs validate without AWS credentials.
- Made format checks and plan errors blocking.
- Required initialized S3 state before cloud operations.
- Replaced tfsec with pinned Trivy after reproducing a parser failure on existing Terraform check blocks; generated and checked SARIF output.
- Added official Linux provider checksums while preserving AWS 5.100.0 and TLS 4.2.1.
- Replaced automatic PR comments and documentation commits with summaries and generated-document artifacts.
- Scoped AWS credentials and token permissions to the jobs that need them.

### Changed
- Corrected Kubernetes resource discovery tags to use the actual EKS cluster name.
- Scoped the EKS control plane to private subnets instead of mixing public and private subnets.
- Tightened Terraform and provider version constraints and started tracking `.terraform.lock.hcl`.
- Added stronger variable validation for subnet CIDRs, scaling values, log types, and reserved tag keys.
- Updated the GitHub Actions workflow to prefer AWS OIDC with access-key fallback for compatibility.
- Rewrote repository documentation to match implemented behavior instead of aspirational claims.

### Removed
- Removed no-op variables that advertised unsupported features such as Pod Security Policy and extra add-on toggles.
