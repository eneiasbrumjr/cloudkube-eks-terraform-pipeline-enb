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

- Terraform `>= 1.6`
- AWS CLI v2
- Git
- Optional:
  `pre-commit`, `tflint`, `tfsec`, `terraform-docs`

Recommended setup:

```bash
git clone https://github.com/YOUR-USERNAME/cloudkube-eks-terraform-pipeline-enb.git
cd cloudkube-eks-terraform-pipeline-enb
pre-commit install
cd infra
terraform init
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
```

From `infra/`:

```bash
terraform fmt -recursive
terraform validate
```

If you have the tools installed locally, also run:

```bash
tflint --config=../.tflint.hcl
tfsec .
terraform-docs .
```

## Pull Request Expectations

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
