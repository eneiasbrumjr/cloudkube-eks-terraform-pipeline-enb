# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning where practical.

## [Unreleased]

### Changed
- Corrected Kubernetes resource discovery tags to use the actual EKS cluster name.
- Scoped the EKS control plane to private subnets instead of mixing public and private subnets.
- Tightened Terraform and provider version constraints and started tracking `.terraform.lock.hcl`.
- Added stronger variable validation for subnet CIDRs, scaling values, log types, and reserved tag keys.
- Updated the GitHub Actions workflow to prefer AWS OIDC with access-key fallback for compatibility.
- Rewrote repository documentation to match implemented behavior instead of aspirational claims.

### Removed
- Removed no-op variables that advertised unsupported features such as Pod Security Policy and extra add-on toggles.
