# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning where practical.

## [Unreleased]

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
