# Validation Results

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
