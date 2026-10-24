# Remote-state and GitHub identity bootstrap

This independent Terraform root defines the backing resources for `infra/`: an S3 state bucket, a customer-managed KMS key, and separate GitHub Actions plan/apply roles. It can create the GitHub OIDC provider or explicitly reuse an existing provider in the same account.

**Repository preparation only:** no AWS authentication, bootstrap apply, state migration or deployment has been performed for this change. Automatic CI validates this root with mocked providers. There is no bootstrap deployment job.

## Ownership and access

| Component | Managed by | Routine GitHub access |
| --- | --- | --- |
| State bucket, encryption key and GitHub identity resources | Bootstrap operator | No administration permissions supplied |
| Bootstrap state and lock | Bootstrap operator | Explicitly denied to both CI roles |
| Workload state | `infra/` plan/apply roles | Plan reads; apply reads and writes |
| Workload lockfile | Both CI roles | Read, create and delete for native S3 locking |
| EKS/VPC/IAM workload resources | `infra/` with separately reviewed permissions | No resource API policy attached by default |

The two states use different keys in the same dedicated bucket. Each has its own `.tflock` object. Inputs reject key collisions. Use only the `default` workspace; a workspace name changes backend paths and is not an environment selector here.

The key policy enables IAM delegation within the explicitly configured account. It does not make the key publicly accessible or create a separate security-administration account. The optional external permissions boundary and workload resource policies still require account-specific review. A valid policy ARN does not prove that its contents are suitably restricted.

## Controls in this root

- S3 versioning, all four Block Public Access settings and `BucketOwnerEnforced` ownership.
- SSE-KMS default encryption with a customer-managed key, key rotation and a 30-day deletion window.
- Bucket policy requiring HTTPS and explicit SSE-KMS upload headers with the exact key ARN. Default bucket encryption alone does not satisfy that upload policy.
- S3 Bucket Keys disabled so the KMS encryption context identifies each object; CI KMS use is scoped to the workload state and lock objects through regional S3.
- `force_destroy = false` and Terraform `prevent_destroy` protection for the bucket and key.
- Exact GitHub audience, subject, immutable repository/owner IDs and `main` ref conditions. Apply also requires the `production` environment.
- Separate roles and scoped backend permissions, with explicit restrictions on bootstrap state, destructive backend operations and mutation of the CI identity configuration.

`prevent_destroy` is a Terraform planning safeguard while the resource declaration remains in configuration. It is not an AWS deletion protection service, and removing the declaration removes that safeguard. Keep operator access, key custody and reviewed changes in place. See [Terraform lifecycle behavior](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#prevent_destroy).

## Prerequisites and explicit decisions

Use Terraform **1.12.2** and the committed AWS **5.100.0** lockfile. AWS credentials are needed only for a future, separately authorized operator execution.

Before that execution, determine:

1. The intended commercial AWS account and region, a globally unique bucket name, and an appropriate name prefix for roles and resource tags.
2. Distinct workload and bootstrap state keys. Confirm that the workload key matches the intended `infra` environment; the GitHub environment label does not select a state key.
3. Whether the GitHub OIDC provider already exists. Choose `existing` with its exact ARN or `create`; do not create a duplicate issuer or take ownership of a shared provider implicitly.
4. The actual GitHub subject format, `legacy` or `immutable`. Neither format is selected automatically. A custom subject template requires an explicit design update. See [../OIDC.md](../OIDC.md).
5. Resource API policies for plan/apply, and an optional permissions boundary, reviewed by the account operator. The defaults attach **no workload resource policy**; the generated roles initially authorize only their backend operations.
6. GitHub `production` reviewers and deployment branch rules. This root does not configure repository settings, secrets or variables.

The operator needs reviewed permissions to manage these S3/KMS/IAM resources and, when reusing an OIDC provider, read its configuration. This repository does not supply an unrestricted administrator policy to satisfy that prerequisite.

## Local checks without AWS credentials

From the repository root:

```sh
terraform -chdir=bootstrap init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap fmt -check -recursive
terraform -chdir=bootstrap validate -no-color
terraform -chdir=bootstrap test -no-color
```

The test runs use `command = plan` with an AWS mock provider. They inspect the real configuration and policy JSON; they do not test IAM evaluation, actual bucket ownership, encryption, OIDC authentication or recovery against AWS.

## Future operator execution

The following commands are a runbook, not operations executed by this repository update. Creating resources incurs AWS charges, including KMS and storage/request charges; review the account and budget first.

1. Copy `terraform.tfvars.example` to the ignored `terraform.tfvars` and replace every placeholder. Review policy contents and OIDC settings before selecting the required modes.
2. Start with `backend.tf` commented. The bootstrap must initially keep its state locally because its remote resources do not exist yet. Use a restricted working directory and retain a protected backup outside it.
3. With the intended operator credentials, initialize, create a saved plan and inspect it:

   ```sh
   terraform -chdir=bootstrap init -input=false -lockfile=readonly
   terraform -chdir=bootstrap plan -out=bootstrap.tfplan
   terraform -chdir=bootstrap show bootstrap.tfplan
   ```

   Confirm the account, names, keys, identity subjects, policy scope and expected resource changes. Saved plans and state may contain sensitive information; keep them out of logs, Git and public artifacts.

4. Only after that plan is authorized, apply the reviewed file:

   ```sh
   terraform -chdir=bootstrap apply bootstrap.tfplan
   ```

5. Preserve the resulting local state and inspect the non-secret outputs:

   ```sh
   terraform -chdir=bootstrap output -json backend_config
   terraform -chdir=bootstrap output -json github_actions_variables
   ```

   The `backend_config` object has separate `bootstrap` and `workload` entries. Copy the correct entry deliberately; the outputs neither write backend files nor migrate state. The GitHub variable output does not configure repository settings.

## Move the bootstrap's own state deliberately

Stop competing runs and protect a copy of the authoritative local state. Verify the new bucket, ownership, versioning, encryption and access policies. AWS recommends waiting 15 minutes after first enabling versioning before object writes/deletes; this is a one-time operator preparation step, not a CI sleep. See [S3 versioning propagation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html).

Activate the partial example in `bootstrap/backend.tf`. Copy the **bootstrap** output entry into an operator-owned `/secure/path/bootstrap.s3.tfbackend` file as HCL attributes, without a `terraform`/`backend` wrapper. Keep `encrypt = true`, `use_lockfile = true`, the exact KMS ARN and the expected account. Review every field, then explicitly migrate:

```sh
terraform -chdir=bootstrap init -migrate-state -backend-config=/secure/path/bootstrap.s3.tfbackend
```

Review the migration prompt and compare the destination lineage/resources with the protected source. Do not automate confirmation, use `-force-copy`, or treat `-reconfigure` as a migration. Keep the protected backup after migration. A fresh operator checkout uses `init -backend-config=/secure/path/bootstrap.s3.tfbackend` against that existing state; it must not start a new local bootstrap state. The CI roles are denied access to this key; future bootstrap maintenance remains an operator task.

## Connect the workload and GitHub workflow

Use the **workload** backend output entry for `infra/backend.tf`. The current manual workflow runs `init` without `-backend-config`, so its reviewed, non-secret destination settings must be present in the versioned backend block. Credentials must stay in the temporary AWS credential chain.

An existing workload needs its own deliberate migration with the correct source/destination; a new workload needs a deliberately unused key. Follow [../REMOTE_STATE.md](../REMOTE_STATE.md). Do not point an existing cluster at empty state or copy bootstrap state into the workload key.

Configure the four Actions variables shown by `github_actions_variables`, the actual role trust and the `production` protections. Then review and provide the separately managed resource API policies. With empty policy inputs, backend access alone is insufficient to plan or apply EKS resources.

The manual jobs remain limited to `infra`, `main` and an explicit operation. The `production` approval happens before the saved apply plan is generated, so it is not approval of that exact plan. A future AWS validation must verify role assumption, permissions, locking and the actual resource plan before any deployment.

## Recovery, changes and limitations

- Use the operator identity for recovery; CI roles cannot read bootstrap state or delete state versions. A routine plan still needs to create/delete its lockfile, even though it cannot write workload state.
- Uploading or copying a recovered state version must explicitly request SSE-KMS and the exact key ARN. The bucket policy rejects absent or different encryption headers. Keep Bucket Keys disabled to preserve the object-scoped KMS conditions.
- Key/name changes can replace protected resources or strand historical versions. Never disable/delete the encryption key while state versions still rely on it. Preserve both state histories and operator recovery access.
- Changing `create` to `existing` is not an automatic ownership transfer for the OIDC provider. Review state ownership and every other role that uses the issuer before removing or changing its declaration.
- Inline protection policies constrain these roles on the named resources. They are not a universal privilege-escalation boundary for arbitrary external policies. IAM creation/PassRole, service-linked roles, KMS, organization policies and the optional boundary require separate review.
- Account-wide audit logging, archival/replication, tested disaster recovery, GitHub settings and live integration are not established by these files. See [../SECURITY_AUDIT.md](../SECURITY_AUDIT.md) and [../TEST_RESULTS.md](../TEST_RESULTS.md).

## Primary references

- [Terraform S3 backend and permissions](https://developer.hashicorp.com/terraform/language/v1.12.x/backend/s3)
- [Terraform backend initialization and migration](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization)
- [S3 SSE-KMS, encryption context and Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html)
- [IAM GitHub OIDC condition keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html)
- [GitHub subject formats](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims)

## Terraform reference

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
