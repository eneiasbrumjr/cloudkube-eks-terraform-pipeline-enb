# Remote state: operator runbook

Reviewed **2026-10-23** for Terraform **1.12.2**. This is documentation for an existing backend; no AWS resources, credentials, IAM roles or state migration were created or verified.

`infra/backend.tf` remains a **commented example**. Local validation still uses the local backend. A separate bootstrap root and GitHub OIDC provisioning remain **pending work of medium effort**; they are outside this batch.

## Prepare the backing resources once

An authorized operator must prepare and verify these resources outside the EKS root before enabling remote state:

- A dedicated S3 bucket in the intended region, with versioning enabled, all four Block Public Access settings enabled, and `BucketOwnerEnforced` ownership.
- Default SSE-KMS encryption using an enabled customer-managed key in the bucket's region, with access for the intended operator and execution roles.
- A bucket policy denying insecure transport (`aws:SecureTransport = false`) and appropriately scoped IAM/key policies. Follow AWS guidance on excluding service principals from network-context denies if service access is needed.
- Protection against bucket/key deletion and retention of state versions. Keep recovery access with an operator; routine execution roles do not need bucket administration, key deletion or object-version deletion.

See AWS guidance on [versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html), [public access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html), [ownership](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ensure-object-ownership.html), [SSE-KMS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html), and [transport policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html#example-bucket-policies-tls-version).

AWS recommends waiting **15 minutes after first enabling versioning** before writing or deleting objects; include this in the one-time setup, not as a CI sleep. [AWS propagation guidance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html).

## Configure the intended state location

The current manual workflow runs `terraform init` **without `-backend-config`**. For CI, deliberately activate the complete commented S3 block in `infra/backend.tf`, replace every placeholder, and review the non-secret bucket, key, region, KMS key ARN and account ID in Git. The backend's `allowed_account_ids` checks the credential account; verify bucket ownership separately.

For **local operator use only**, a partial block is an optional alternative:

```hcl
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
```

Move the other five destination arguments into an operator-owned `production.s3.tfbackend` file as top-level attributes, without a `terraform`/`backend` wrapper. Keep that file outside Git, or explicitly ignore its local path. Supply it with `-backend-config=/secure/path/production.s3.tfbackend` only when using this local alternative. It is **not delivered to the current runner**; a partial block alone is insufficient for its unattended init.

Keep `encrypt = true` and `use_lockfile = true`. Locking is a Terraform backend feature, already supported by CLI 1.12.2; it does not require an AWS provider upgrade or a new DynamoDB table. Existing DynamoDB users need a coordinated client migration before removing their old locking configuration. [S3 backend reference](https://developer.hashicorp.com/terraform/language/v1.12.x/backend/s3).

Use **only the `default` Terraform workspace** with an explicit, distinct key for each environment, such as `cloudkube/production/terraform.tfstate`. Confirm that the selected key matches the infrastructure variables and intended account before every operation, including Terraform's `environment` input. This example does not implement automatic backend selection by environment. Non-default workspaces change object paths and permissions and are outside this runbook.

Backend blocks cannot refer to Terraform variables, locals or resource outputs. Supply temporary credentials through the AWS credential chain; never put access keys or tokens in `backend.tf` or `-backend-config`. Backend settings are copied into local metadata and saved plans. [Backend configuration and credential handling](https://developer.hashicorp.com/terraform/language/v1.12.x/backend).

## Scope state and lockfile access

For a state key `cloudkube/production/terraform.tfstate`, use these **exact object ARNs**, replacing `BUCKET`:

| Resource | Plan role | Apply role |
|---|---|---|
| `arn:aws:s3:::BUCKET` | `s3:ListBucket` | `s3:ListBucket` |
| `arn:aws:s3:::BUCKET/cloudkube/production/terraform.tfstate` | `s3:GetObject` | `s3:GetObject`, `s3:PutObject` |
| `arn:aws:s3:::BUCKET/cloudkube/production/terraform.tfstate.tflock` | `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` | Same lockfile permissions |

Restrict object access to those ARNs, not `BUCKET/*`. Scope listing to the required prefixes when designing the policy. Terraform 1.12.2 also lists `env:/` for workspace discovery; a denial there is tolerated for the default workspace but can emit a warning. [Backend implementation](https://github.com/hashicorp/terraform/blob/v1.12.2/internal/backend/remote-state/s3/backend_state.go#L34-L88).

Routine plan/apply does **not** need `s3:DeleteObject` on the state, `s3:DeleteObjectVersion`, or `s3:DeleteBucket`. Recovery privileges belong to the operator. This table covers backend access only, not the separate AWS permissions required to inspect or manage EKS resources. [S3 backend permissions](https://developer.hashicorp.com/terraform/language/v1.12.x/backend/s3#permissions-required).

Migration is a separate operator task requiring the appropriate source and destination state permissions; it is not delegated to either CI job by this table.

Both roles need `kms:Encrypt`, `kms:Decrypt` and `kms:GenerateDataKey` on the configured KMS key, with corresponding key-policy authorization. A plan still writes its lockfile, so read-only state access does not mean decrypt-only KMS access. [KMS backend requirements](https://developer.hashicorp.com/terraform/language/v1.12.x/backend/s3#s3-state-storage).

The plan/state distinction is supported by the 1.12.2 implementation: the default workspace is always recognized, and refreshed state is saved in a plan rather than persisted until apply. Migration and creation of other workspaces require write access. [Workspace initialization](https://github.com/hashicorp/terraform/blob/v1.12.2/internal/backend/remote-state/s3/backend_state.go#L175-L248), [plan behavior](https://github.com/hashicorp/terraform/blob/v1.12.2/internal/backend/local/backend_plan.go#L154-L174).

## Initialize or migrate deliberately

These commands are operator instructions, **not actions executed by this repository update**. They use the complete backend block; add the `-backend-config` argument above only for the optional local partial configuration. First stop competing Terraform runs, confirm the default workspace and source/destination account, bucket and key, and preserve a protected backup of the authoritative state.

1. For existing local or remote state, activate the reviewed backend block, then run from the repository root:

   ```sh
   terraform -chdir=infra init -migrate-state
   ```

   Review the migration prompt. Do not automate confirmation or use `-force-copy`. Preserve the source and backup until the destination state has been checked.

2. For a fresh working directory that should use an already selected backend, initialize it with:

   ```sh
   terraform -chdir=infra init
   ```

   A new environment must have a deliberately unused key; an existing environment must point to its authoritative state, not an empty replacement.

3. Use `init -reconfigure` only when deliberately reinitializing backend settings without copying state. It is **not** a substitute for `-migrate-state`. [Terraform init reference](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization).

After migration, inspect the destination state locally, compare its lineage/resources with the protected source, and review a normal plan before applying. Do not print state into CI logs or upload state/backups as artifacts. Do not delete the source simply because `init` succeeded.

If a future bootstrap configuration creates the backend resources, keep its own state separate and operator-controlled. Back it up before any migration; GitHub execution roles must not gain access to that bootstrap state or permission to delete its backing resources.

## Recovery

- **Stale lock:** identify the lock owner/run and confirm it has stopped before considering `terraform force-unlock LOCK_ID`. Never automatically remove a lock or use `-lock=false` to bypass a live writer. [Terraform locking guidance](https://developer.hashicorp.com/terraform/language/state/locking).
- **Deleted or overwritten state:** stop all writers, preserve the current state and relevant S3 versions, and have the recovery operator inspect the candidate version. Copying a known-good version to a new current version preserves history; it does not undo changes already made to AWS resources. Review the reconciled plan before resuming. [S3 version recovery](https://docs.aws.amazon.com/AmazonS3/latest/userguide/RestoringPreviousVersions.html).
- **Manual state push:** Terraform checks lineage and serial. Investigate a mismatch instead of routinely overriding it with `-force`. [State push safeguards](https://developer.hashicorp.com/terraform/cli/commands/state/push).
- **Protected copies:** keep state and saved plans out of Git and public artifacts, restrict local file access, and retain an encrypted backup outside the working directory. Do not disable/delete the KMS key while retained state versions still depend on it.

No cloud authentication, backend migration, lock recovery, plan or apply was performed for this documentation change.
