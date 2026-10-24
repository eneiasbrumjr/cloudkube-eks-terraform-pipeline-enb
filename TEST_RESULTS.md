# Validation Results

Last reviewed: 2026-10-23

## Remote-state and GitHub identity bootstrap - 2026-10-23

This change follows merge commit `4a93b0c88e3955f1092c0ee5fd5b114874d04496`. It adds a separate operator-owned Terraform root and extends credential-free validation, scanning and documentation to both roots. Workload resources, Terraform 1.12.2, AWS 5.100.0, TLS 4.2.1 and the workload lockfile are unchanged; the bootstrap lockfile reuses the existing AWS version and official hashes.

| Check | Local result |
| --- | --- |
| Terraform fmt and whitespace checks | Passed |
| Backend-free init with readonly lockfiles, both roots | Passed using verified provider packages without copying the cache |
| Terraform validation, both roots | Passed |
| Workload mock plans | **32 passed, 0 failed** |
| Bootstrap mock plans | **26 passed, 0 failed**: 12 state and 14 identity cases |
| Offline cloud-guard suite | **16 passed, 0 failed** |
| actionlint 1.7.12 and scanner Bash syntax | Passed |
| Trivy 0.76.1 final example-input scan | **0 MEDIUM/HIGH/CRITICAL findings**; both roots identified, no missing-input warnings or parsing errors |
| Scanner canaries in temporary fixtures | Findings from both roots in one SARIF; invalid bootstrap syntax blocked the scan |
| terraform-docs 0.17.0 | Generated separate workload/bootstrap references in isolated copies |
| Independent source review | State/header/policy compatibility and IAM ownership/trust reviewed; no blocking issue remained |

All 58 Terraform runs use `command = plan` with mock providers. Bootstrap fixtures supply only computed identities or explicit responses for a reused OIDC provider; policy assertions inspect the real `jsonencode` output. Coverage includes versioning, ownership/public blocking, encryption/transport policies, distinct state/lock keys, non-secret backend outputs, exact legacy/immutable trust, provider create/reuse, state/lock permissions, KMS service/object contexts, protected resources and external policy/boundary inputs. Rejections cover malformed inputs, state collisions, cross-account providers/policies, wrong issuer/audience, unsupported subject modes, AWS-managed administrator policy input and excessive inline-policy size. `prevent_destroy` was checked by source review, not a source-text assertion test or a real destroy.

The final scanner uses `bootstrap/terraform.tfvars.example` to evaluate the required inputs. A temporary canary proved that Trivy's `--tf-vars` applies across roots. In the committed configuration the only shared variable is `aws_region`, and its example value equals the workload default. The first scan without this file warned about missing bootstrap inputs; that scan was not used as the final evidence. The final run had no such warning, no source changes during execution, and used the pinned binary's bundled checks with fresh cache. No findings were suppressed and severity/policy settings were preserved.

The workflow's manual plan/apply jobs remain unchanged and target only `infra`; the new bootstrap has no deployment dispatch. Automatic jobs now validate both roots and upload separate generated-document artifacts, plus one combined repository-relative SARIF report. Workflow filters include bootstrap changes. The shared pre-commit scanner requires no separate hook configuration change.

Commands from the repository root:

```sh
terraform -chdir=infra init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap init -backend=false -input=false -lockfile=readonly
terraform fmt -check -recursive
terraform -chdir=infra validate -no-color
terraform -chdir=bootstrap validate -no-color
terraform -chdir=infra test -no-color
terraform -chdir=bootstrap test -no-color
python3 -B -m unittest discover -s scripts/tests -p 'test_*.py'
actionlint .github/workflows/terraform-eks-pipeline.yml
bash -n scripts/scan-terraform.sh
bash scripts/scan-terraform.sh /tmp/cloudkube-bootstrap-results.sarif
```

Provider RPC required local socket access outside the sandbox; AWS credentials/configuration were disabled. An initial sandbox-only bootstrap validation could not start provider RPC; the complete validation and suites subsequently passed with that local restriction lifted. TFLint and the full pre-commit suite were not rerun. Hosted PR and post-merge evidence is recorded in the associated pull request and Actions runs.

**No AWS authentication, real cloud plan/apply, provisioning, state migration, recovery or deployment was performed.** Mock tests check configuration and generated policy structure, not AWS authorization or service behavior. Operator permissions, external policy contents, actual OIDC subjects, GitHub protections, bucket/key ownership, encryption and live locking/recovery still require validation before use. Bootstrap has backend-only role permissions by default and starts with local state. See [bootstrap/README.md](bootstrap/README.md).

## State and OIDC maintenance - 2026-10-23

This maintenance follows merge commit `45217768fc5ee020e1e3a88088b18460180f9077`. It changes the manual-job identity contract, initialized-backend guard, inactive S3 example, local ignore patterns and operator documentation. Terraform 1.12.2, AWS provider 5.100.0, TLS provider 4.2.1, infrastructure resources, lockfile and scanner policies are unchanged.

| Check | Local result |
| --- | --- |
| Terraform formatting and `git diff --check` | Passed |
| Backend-free init with the read-only lockfile | Passed using the existing verified provider cache |
| Terraform schema validation | Passed |
| Existing mocked-provider suite | **32 passed, 0 failed** |
| Offline cloud-guard suite | **16 passed, 0 failed**, including the exact CI invocation from `infra/` |
| actionlint 1.7.12 | Passed for the modified workflow |
| Shared Trivy 0.76.1 scan | Completed; **0 findings at MEDIUM or above** |
| terraform-docs 0.17.0 | Generated inputs/outputs with one marker pair in an isolated copy |
| Local ignore patterns | State/backups, variable JSON, backend config and saved plans ignored; provider lockfile, source and example files retained |
| Independent source review | Confirmed manual/main gates and the order: settings check, OIDC, init, backend check, plan/apply |

The guard's synthetic cases cover required settings, malformed or wrong-account roles, identical roles, workspace selection, missing/invalid metadata, non-S3 backends, encryption/locking booleans, account allowlist, region, bucket/key, and errors that do not print configuration contents. These tests are part of the automatic credential-free job; edits to the guard and its tests match the workflow path filters.

The credentials action is pinned to [v6.3.0 commit `e1253824e5c10ff9df46874f81ed3ec929e19cfd`](https://github.com/aws-actions/configure-aws-credentials/tree/e1253824e5c10ff9df46874f81ed3ec929e19cfd). The tag's Git object resolves directly to that commit, and its supported inputs were checked in `action.yml`. Backend metadata format and S3 field types were checked against the [Terraform 1.12.2 writer](https://github.com/hashicorp/terraform/blob/v1.12.2/internal/command/workdir/backend_state.go) and [S3 schema](https://github.com/hashicorp/terraform/blob/v1.12.2/internal/backend/remote-state/s3/backend.go).

Commands from the repository root, with the pinned tools installed:

```sh
python3 -B -m unittest discover -s scripts/tests -p 'test_*.py'
terraform -chdir=infra init -backend=false -input=false -lockfile=readonly
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate -no-color
terraform -chdir=infra test -no-color
actionlint .github/workflows/terraform-eks-pipeline.yml
bash scripts/scan-terraform.sh /tmp/cloudkube-state-oidc-results.sarif
```

Local Terraform validation and tests ran with AWS credentials/configuration disabled; provider RPC required access outside the local sandbox's socket restriction. The guard uses Python's standard library and no network client. TFLint and the full pre-commit suite were not rerun. Hosted PR and post-merge results are recorded in the associated pull request and Actions runs.

**No AWS authentication, real cloud plan/apply, backend activation, migration, deployment or paid resource creation was performed.** The guard examines local settings and metadata after init; it does not independently verify live bucket ownership/policies, KMS, versioning, locking behavior, role trust/permissions or GitHub environment protections. The complete bootstrap remains pending. See [OIDC.md](OIDC.md) and [REMOTE_STATE.md](REMOTE_STATE.md) for the operator-owned work.

## Effective node egress and private paths - 2026-10-23

This change follows merge commit `49a95bff159816a28d6712480bcb28f1a0d34658`. It attaches only the custom node SG through a launch template, replaces unrestricted custom-group egress with explicit traffic paths, and adds private AWS endpoints. Terraform 1.12.2, AWS provider 5.100.0, TLS provider 4.2.1, the lockfile, the shared scanner, and the manual cloud-operation gates are unchanged.

| Check | Local result |
| --- | --- |
| Terraform formatting and `git diff --check` | Passed |
| Backend-free initialization with the read-only lockfile | Passed using the verified local provider packages |
| Terraform schema validation | Passed with no configuration errors |
| Mocked AWS/TLS provider regression suite | **32 passed, 0 failed, 0 skipped**; all runs use `command = plan` |
| Shared Trivy 0.76.1 scan | Completed; SARIF 2.1.0 with **0 findings at MEDIUM or above** |
| actionlint 1.7.12 | Passed for the unchanged workflow |
| terraform-docs 0.17.0 | Generated tables in an isolated copy, including new inputs/outputs and one marker pair |

The suite contains **25 root contract runs, 4 EKS module runs and 3 VPC module runs**. It checks actual resource arguments for LT-to-node-group wiring, exclusive node SG attachment, numeric LT version, AL2023, required metadata tokens, hop limit, encrypted gp3 disk, explicit SG source/destination/port paths, private DNS/endpoints, S3 route-table association and object-read policy, optional network/IAM settings, and no-NAT/single-NAT/per-AZ routing. Negative cases cover endpoint modes, invalid/broad CIDRs, external egress without NAT, SSH input pairs, webhook ports, required IRSA and invalid per-AZ subnet counts.

Fixtures supply only synthetic provider responses and computed identities where needed: distinct SG IDs, a launch-template ID/version, and the S3 prefix-list ID. SG associations, traffic rules, endpoints, metadata and disk settings under assertion come from the source configuration. The final suite completed in approximately 39 seconds without source changes during execution. The initial local run identified one test expectation needing adjustment: rejection of private API access stops Terraform before it evaluates a dependent public-mode validation. The final test expects the blocking private-access rejection actually emitted.

The shared scan changed from **2 CRITICAL AWS-0104 findings to 0 findings at MEDIUM or above**, without ignores or scanner-policy changes. No conclusion is made about excluded severities or every possible input override. The EKS-created primary control-plane SG remains outside this module's rule ownership and is not fully represented by the source scan. See [SECURITY_AUDIT.md](SECURITY_AUDIT.md).

Commands, after installing the pinned tools:

```sh
terraform -chdir=infra init -backend=false -input=false -lockfile=readonly
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate -no-color
terraform -chdir=infra test -no-color
actionlint .github/workflows/terraform-eks-pipeline.yml
bash scripts/scan-terraform.sh /tmp/cloudkube-egress-results.sarif
```

Local initialization used the existing verified provider cache without copying or changing it. Validation and tests ran with no AWS credentials; provider RPC needed to run outside the local sandbox's socket restriction. Terraform provider mocks validate local configuration but synthesize plan/data responses and do not configure an AWS client. They do not verify real API validation, replacement execution, live SG attachments, node bootstrap, IAM authorization, DNS, image pulls, IRSA/CSI, or SSM.

The independent source review checked SG identities, endpoint paths, creation dependencies, provider-supported LT fields and replacement behavior. The [migration document](NETWORK_SECURITY.md#existing-cluster-migration-and-runtime-validation) requires temporary old/new node communication and endpoint ingress before a private-DNS transition; the S3 policy affects every client of the private route tables. Names permitting replacement overlap do not establish availability.

No AWS authentication, remote backend access, real cloud plan, apply, deployment, or paid resource creation was performed. TFLint and the entire pre-commit suite were not rerun; the shared scan, required Terraform checks, workflow lint and docs generation above are the executed gates. Hosted PR and post-merge results are recorded in the associated pull request and Actions runs.

## EKS compatibility and network-default validation - 2026-10-23

This change follows merge commit `ea2c671c4a677c9963cefdfca76a99d603bbba9a`. The candidate changes the new-cluster Kubernetes default to 1.36, makes the AL2023 x86_64 node AMI explicit, disables public API access and automatic public-IP assignment by default, and adds blocking endpoint input guards. Terraform runs on 1.12.2 with AWS provider 5.100.0 and TLS provider 4.2.1; provider versions and the dependency lockfile are unchanged. The minimum supported Terraform version is now 1.11 for plan-time provider mocks.

| Check | Local result |
| --- | --- |
| Terraform format check and `git diff --check` | Passed |
| Backend-free initialization with the readonly lockfile | Passed with the verified local provider packages |
| Terraform schema validation | Passed; zero errors and zero warnings |
| Terraform tests with mocked AWS and TLS providers | **13 passed, 0 failed**; all runs use `command = plan` |
| actionlint 1.7.12 | Passed for the workflow containing the new test step |
| Shared Trivy 0.76.1 scan | Passed in advisory mode; SARIF 2.1.0 with **2 CRITICAL findings**, both AWS-0104 |
| terraform-docs 0.17.0 | Generated the README input/output tables in an isolated copy |

The test suite contains ten root-module cases, two EKS-module cases, and one VPC-module case. Positive cases cover private defaults, explicit public CIDRs, version overrides, the explicit AL2023 AMI, add-on version filters, disabled subnet auto-IP assignment, and preserved NAT/Elastic IP/internet-gateway routing and subnet associations. Seven negative cases require validation failures for disabled endpoint modes, a missing public allowlist, `/0` (including a noncanonical address), IPv6, malformed CIDRs, and the removed 1.29 version.

Synthetic provider responses supply computed IDs, availability-zone names, an add-on response, and an OIDC certificate fixture. The endpoint flags, CIDR inputs, Kubernetes versions, AMI, subnet settings, and route arguments under assertion come from the real configuration. Tests were run without cloud credentials. Initialization uses provider packages; the test plans do not query an AWS account, make TLS connections, or create resources.

The security result changed from six findings (four CRITICAL and two HIGH) to two CRITICAL unrestricted-egress findings. No ignore rule or scanner policy change was added. [SECURITY_AUDIT.md](SECURITY_AUDIT.md) explains why the remaining custom-group rules and the EKS-managed security group require a separate effective-network review.

Commands from the repository root, after installing the pinned tools:

```sh
terraform -chdir=infra init -backend=false -input=false -lockfile=readonly
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate -no-color
terraform -chdir=infra test -no-color
actionlint .github/workflows/terraform-eks-pipeline.yml
bash scripts/scan-terraform.sh /tmp/cloudkube-results.sarif
```

Local initialization reused verified provider packages after clearing incomplete temporary cache copies; neither the lockfile nor the provider binaries needed modification. The final checks passed. Hosted results for this revision are recorded in its pull request and GitHub Actions runs.

These results do not establish regional EKS or add-on availability, successful AL2023 bootstrap, workload compatibility, actual security-group attachments, or private-endpoint connectivity. No AWS authentication, remote backend access, real cloud plan, apply, or deployment was performed. TFLint and the full pre-commit suite were not rerun in this change. See [COMPATIBILITY.md](COMPATIBILITY.md) before planning any existing-environment upgrade.

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

At this earlier tooling-maintenance revision, the finding baseline remained six occurrences across four rules: four critical and two high. Tests used temporary checkout copies and an isolated pre-commit cache. Only the `terraform_trivy` hook was executed; the remaining hooks were preserved and their full suite was not revalidated. The existing pre-commit-hooks 4.5.0 manifest emitted a non-blocking warning about old stage names.

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
