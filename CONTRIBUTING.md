# Contributing

Thanks for contributing to CloudKube EKS Terraform Pipeline.

The project aims to stay small, readable, and honest about what it implements. Contributions that improve correctness, security, maintainability, documentation, and contributor experience are preferred over broad feature sprawl.

## Ground Rules

- Keep Terraform changes explicit and reviewable.
- Do not add README or marketing claims that the code does not implement.
- Prefer backward-compatible changes when practical.
- If a change is intentionally breaking, explain why in the pull request.
- Update documentation when behavior, inputs, outputs, or workflow expectations change.

## Local Setup

Prerequisites:

- Terraform `1.12.2` to match the workflow (the configuration requires `>= 1.11, < 2.0` for plan-time provider mocks and cross-variable input validation)
- Git, Bash, and Python 3
- Optional:
  `pre-commit >= 4.4.0`, `tflint`, `terraform-docs`
- [Trivy `0.76.1`](https://github.com/aquasecurity/trivy/releases/tag/v0.76.1) for the local security hook

Install Trivy separately and make it available on `PATH`; pre-commit does not install it. The hook reports a clear failure if Trivy is missing or has a different version. AWS CLI v2 and AWS credentials are only needed for cloud operations.

Recommended setup:

```bash
git clone https://github.com/YOUR-USERNAME/cloudkube-eks-terraform-pipeline-enb.git
cd cloudkube-eks-terraform-pipeline-enb
pre-commit install
terraform -chdir=infra init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap init -backend=false -input=false -lockfile=readonly
```

## Development Workflow

1. Create a branch from `main`.
2. Make the smallest reasonable change that solves the problem.
3. Run the checks below.
4. Update docs if the public interface changed.
5. Open a pull request with a clear summary and rollback notes when relevant.

## Checks to Run

From the repository root:

```bash
pre-commit run --all-files
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

To run only the security hook:

```bash
pre-commit run terraform_trivy --all-files
```

The hook and GitHub Actions use the same `scripts/scan-terraform.sh` script. It scans Terraform in both `infra` and `bootstrap` from the repository root, including commits that only remove files, and excludes Git metadata and downloaded Terraform caches. It uses Trivy's bundled checks with an empty temporary cache and reports findings at medium severity or above. Findings remain advisory; tool, parsing, and report errors block the check. The remaining pre-commit hooks retain their existing tools and settings.

The scanner supplies `bootstrap/terraform.tfvars.example` as a synthetic input scenario so required bootstrap values can be evaluated. Trivy's `--tf-vars` flag applies to all scanned roots; currently only `aws_region` is shared and its example equals the workload default. Review that shared scope when changing example inputs or adding variables. This scan does not validate an operator's complete deployment configuration.

For a direct scan, or to retain a SARIF (Static Analysis Results Interchange Format) report:

```bash
bash scripts/scan-terraform.sh
bash scripts/scan-terraform.sh /tmp/cloudkube-results.sarif
```

The default invocation removes its temporary report and cache when it finishes. A supplied relative report path is resolved from the repository root.

Run these checks for each Terraform root:

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra test -no-color
terraform -chdir=bootstrap fmt -check -recursive
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap test -no-color
```

From each root, if you have the tools installed locally, also run:

```bash
tflint --config=../.tflint.hcl
terraform-docs .
```

## Pull Request Expectations

The tests in `infra/tests` use mocked AWS and TLS providers, and every run uses `command = plan`. They cover endpoint and network input guards, version/AMI choices, launch-template SG attachments, metadata/storage settings, allowed traffic paths, private endpoints, optional services, and subnet routing without AWS credentials or resource creation. Provider downloads during `init` still require registry access. Mock tests do not establish regional EKS availability, add-on compatibility with real workloads, or deployment readiness.

When adding a test, keep these automatic runs isolated from real provider operations. Cloud integration checks require a separate, deliberately configured environment.

The independent `bootstrap/tests` mock plans inspect S3/KMS controls, backend key separation and the actual JSON produced for OIDC trust and IAM permissions. Fixtures must supply only provider-computed identities or explicit external-provider responses; do not replace the policy under test with fixture JSON. Preserve explicit operator inputs and keep bootstrap/state migration out of the manual EKS jobs. Both roots have their own committed provider lockfile.

The cloud-guard suite uses synthetic environment values and backend metadata. It checks that missing or inconsistent identity settings and unsafe backend settings stop the manual path; it makes no AWS calls. Keep its checks before credential acquisition and before plan, respectively. If changing the helper or its tests, preserve their workflow path filters. See [OIDC.md](OIDC.md) and [REMOTE_STATE.md](REMOTE_STATE.md) for the operator setup that remains outside these tests.

A good pull request for this repository should:

- describe the problem and the change clearly
- call out any security or cost impact
- mention breaking changes explicitly
- include updated documentation when inputs, outputs, workflow behavior, or defaults change
- avoid unrelated cleanup

## Areas That Usually Need Extra Care

- EKS endpoint exposure and CIDR defaults
- IAM and IRSA changes
- Kubernetes discovery tags on subnets and security groups
- Remote-state guidance
- GitHub Actions authentication and permissions
- Claims in `README.md`, `PROJECT_STATUS.md`, and `SECURITY_AUDIT.md`

## Reporting Security Issues

Please do not open a public issue for a suspected security problem. Send details to `eneiasbrumjr@gmail.com` with the subject `SECURITY`.

## Code of Conduct

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
