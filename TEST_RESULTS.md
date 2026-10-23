# Validation Results

Last reviewed: 2026-10-23

## Workflow repair validation - 2026-10-23

The checks below ran against the candidate based on commit `5e6634a6691dfc8fdb6599bc8b7ca5e011a1d468`. Infrastructure `.tf` files were unchanged; the dependency lockfile gained Linux checksums and aligned constraint metadata without changing provider versions.

| Check | Result |
| --- | --- |
| actionlint 1.7.12 | Original workflow: four invalid secret references in conditions. Repaired workflow: passed. |
| Terraform 1.12.2 format check | Passed |
| Backend-free initialization with readonly lockfile | Original lock: installed providers but omitted needed local content hashes. Corrected lock: Linux checksums present. |
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

### Security findings and limits

The six SARIF results correspond to four rules: public EKS endpoint access, a public endpoint CIDR, unrestricted security-group egress, and public-IP assignment in public subnets. These are findings from static configuration analysis, not evidence of an exposed deployed environment. They were not remediated in this workflow repair.

Trivy runs with its bundled checks for reproducibility. The advisory finding policy is preserved, but the workflow also checks for Terraform parsing diagnostics because Trivy can return zero even when a file fails to parse. A successful workflow does not certify security or production readiness.

No AWS authentication, remote backend access, Terraform plan/apply, or deployment was executed. Local CLI validation does not validate action-container downloads, GitHub permissions, or the hosted runner. The GitHub Actions run remains the source for remote execution status.

`pre-commit` and `tflint` were not run. The optional local pre-commit configuration still includes tfsec and needs a separate tooling update; the CI workflow uses Trivy.

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
