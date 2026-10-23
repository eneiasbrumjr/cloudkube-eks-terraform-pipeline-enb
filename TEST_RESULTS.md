# Validation Results

Last reviewed: 2026-10-23

## Tooling alignment validation - 2026-10-23

This maintenance follows merge commit `5dd2f1d941ac3426f96f4499b5df420762c7a00a`. Infrastructure source, Terraform 1.12.2, and provider versions remain unchanged.

The automatic checks use the following Node24 actions, each pinned to the full commit recorded in the workflow:

| Action | Release |
| --- | --- |
| actions/checkout | 5.1.0 |
| hashicorp/setup-terraform | 4.0.1 |
| actions/upload-artifact | 7.0.2 |
| github/codeql-action/upload-sarif | 4.39.1 |

The shared `scripts/scan-terraform.sh` requires Trivy 0.76.1, uses an empty temporary cache, validates its SARIF report, and preserves advisory findings with blocking operational and parsing errors. The local hook requires pre-commit 4.4 or newer; validation used pre-commit 4.7.0.

| Check | Result |
| --- | --- |
| actionlint 1.7.12 and Bash syntax check | Passed |
| pre-commit configuration validation | Passed |
| Shared script with an explicit report path | Passed; SARIF 2.1.0 with six findings |
| Shared script without arguments, invoked outside the checkout root | Passed; six findings, no files left in the checkout |
| terraform_trivy hook with the full repository configuration | Passed; findings remained visible |
| Malformed Terraform fixture through the script and through the hook | Both failed with the expected parsing error |
| Trivy absent from PATH | Failed with installation guidance |
| Simulated incompatible Trivy version | Failed before scanning, with required and detected versions |
| Source and temporary-file integrity | Infrastructure, script, and configuration hashes unchanged by tests; no scan outputs left in the checkouts |

The finding baseline remains six occurrences across four rules: four critical and two high. Tests used temporary checkout copies and an isolated pre-commit cache. Only the `terraform_trivy` hook was executed; the remaining hooks were preserved and their full suite was not revalidated. The existing pre-commit-hooks 4.5.0 manifest emitted a non-blocking warning about old stage names.

Cloud authentication actions and the manual plan/apply gates were preserved. No AWS authentication, remote backend access, Terraform plan/apply, or deployment was executed. Hosted execution and the post-merge SARIF integration are recorded in the associated pull request and its GitHub Actions runs.

Commands from the repository root:

```sh
actionlint .github/workflows/terraform-eks-pipeline.yml
bash -n scripts/scan-terraform.sh
pre-commit validate-config
pre-commit run terraform_trivy --all-files
bash scripts/scan-terraform.sh /tmp/cloudkube-results.sarif
```

## Workflow repair validation - 2026-10-23

The checks below ran against the candidate based on commit `5e6634a6691dfc8fdb6599bc8b7ca5e011a1d468`. Infrastructure `.tf` files were unchanged; the dependency lockfile gained Linux checksums and aligned constraint metadata without changing provider versions.

| Check | Result |
| --- | --- |
| actionlint 1.7.12 | Original workflow: four invalid secret references in conditions. Repaired workflow: passed. |
| Terraform 1.12.2 format check | Passed |
| Backend-free initialization with readonly lockfile | Original lock: installed providers but omitted needed local content hashes. Corrected lock: initialization passed on the GitHub-hosted runner. |
| Terraform 1.12.2 validation after lock correction | Passed: zero errors and zero warnings |
| tfsec 1.28.14 on existing source | Failed to parse the existing `check` blocks; replaced in CI |
| Trivy 0.76.1 configuration scan | Completed with SARIF 2.1.0 and six findings: four critical, two high |
| Exact workflow scanner shell | Current infrastructure passed; the same source with malformed HCL failed with the expected parsing error |
| terraform-docs 0.17.0 | Generated README tables with one matching pair of documentation markers |
| S3 backend guard | Seven temporary fixtures passed: S3 accepted; missing, invalid, local, other-backend, and incompatible-format metadata rejected |
| SARIF summary script | Five temporary fixtures passed: reports summarized; missing, malformed, and wrong-version reports rejected |

Tools were downloaded from official releases and checked against the published checksums. Terraform used AWS provider `5.100.0` and TLS provider `4.2.1`. No provider upgrade was performed.

### Commands reproduced

```sh
# Repository root
actionlint .github/workflows/terraform-eks-pipeline.yml

# infra/
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate -json

# Regenerate the Linux content hashes when needed, from infra/
terraform providers lock -platform=linux_amd64 \
  registry.terraform.io/hashicorp/aws registry.terraform.io/hashicorp/tls

# Repository root
trivy config --skip-check-update --disable-telemetry \
  --format sarif --severity MEDIUM,HIGH,CRITICAL --exit-code 0 \
  --output results.sarif infra
terraform-docs markdown table --config .terraform-docs.yml \
  --output-mode inject --output-file ../README.md infra
```

The scanner and documentation commands ran in temporary copies or with temporary outputs. Their output files were not committed.

### GitHub-hosted validation

[Run #12](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/actions/runs/40020683358) completed successfully on 2026-10-23 for [PR #5](https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb/pull/5), at head commit `8ee0c083924d7db2af9e6f740898d1625bde84be`.

- Terraform Format & Validate: passed, including backend-free initialization with the readonly lockfile.
- Security Report (Advisory): passed, including report validation and artifact upload.
- Generate Terraform Documentation: passed, including the action container and artifact upload.
- Terraform Plan (Manual) and Terraform Apply (Manual): skipped as intended for a pull request.

The run produced `trivy-results` and `terraform-documentation` artifacts with a seven-day retention period. The direct SARIF upload to GitHub Security is intentionally skipped on pull requests, so that integration is not covered by this PR run.

### Security findings and limits

The six SARIF results correspond to four rules: public EKS endpoint access, a public endpoint CIDR, unrestricted security-group egress, and public-IP assignment in public subnets. These are findings from static configuration analysis, not evidence of an exposed deployed environment. They were not remediated in this workflow repair.

Trivy runs with its bundled checks for reproducibility. The advisory finding policy is preserved, but the workflow also checks for Terraform parsing diagnostics because Trivy can return zero even when a file fails to parse. A successful workflow does not certify security or production readiness.

No AWS authentication, remote backend access, Terraform plan/apply, or deployment was executed. The GitHub Actions run verifies the hosted checks described above; it does not establish cloud deployment or Kubernetes runtime readiness.

During this earlier workflow repair, `pre-commit` and `tflint` were not run and the local hook still used tfsec. The tooling maintenance recorded above subsequently replaced that hook with the shared Trivy scan.

## Historical validation - 2026-04-13

Last reviewed: 2026-04-13

## Commands Run

- `terraform fmt -check -recursive`
- `terraform fmt -recursive`
- `terraform validate`

## Outcome

- `terraform fmt -check -recursive`: passed before edits
- `terraform fmt -recursive`: applied formatting changes after edits
- `terraform validate`: passed after the repository updates

## Environment Notes

- Terraform version used locally: `1.12.2`
- Locked providers in `infra/.terraform.lock.hcl`:
  `hashicorp/aws` `5.100.0`, `hashicorp/tls` `4.2.1`

## Not Run

- `tflint`
- `tfsec`
- `terraform-docs`

Those tools were referenced by the repository configuration but were not installed in the local shell environment during this review.
