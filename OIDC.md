# GitHub Actions OIDC

Reviewed: 2026-10-23. This guide describes the configuration expected by the manual cloud jobs. This repository change does **not** create AWS roles, an OIDC provider, policies, GitHub environment protections, or AWS resources. Authentication and deployment remain unverified in AWS.

## Required GitHub Actions Variables

Configure the following Actions variables (`vars.*`) for this repository:

| Variable | Required value |
| --- | --- |
| `AWS_ACCOUNT_ID` | The intended 12-digit AWS account ID. |
| `AWS_REGION` | The deployment and remote-state region. |
| `AWS_PLAN_ROLE_ARN` | IAM role ARN for the manual plan job on `main`. |
| `AWS_APPLY_ROLE_ARN` | A different IAM role ARN for the manual apply job using `production`. |

Both role ARNs must belong to `AWS_ACCOUNT_ID`. The workflow uses OIDC only; it does not fall back to stored access keys. Its local guard checks the configuration before authentication. Passing that guard does not establish that roles exist or have appropriate trust and permissions. `id-token: write` allows requesting an OIDC token; it does not itself grant AWS permissions. See [GitHub's OIDC guidance](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

## Confirm the Subject Before Configuring Trust

The GitHub provider must use `https://token.actions.githubusercontent.com` with audience `sts.amazonaws.com`. Replace `<AWS_ACCOUNT_ID>` and each `<OBSERVED_..._SUB>` below with verified values; do not deploy the placeholders or replace them with wildcards.

For this repository, the immutable IDs are `repository_id = 1016370567` and `repository_owner_id = 57417495`, obtained from the [repository metadata](https://api.github.com/repos/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb). A fork or transfer needs its own reviewed identity settings.

The historical subject format would be:

| Job | Expected legacy `sub` |
| --- | --- |
| Plan, no environment | `repo:eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb:ref:refs/heads/main` |
| Apply, `production` | `repo:eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb:environment:production` |

Confirm the actual subject setting/claim before use. GitHub now documents an immutable format for repositories created after 2026-07-15, renames/transfers after that date, and opt-ins. Its repository prefix here would be `repo:eneiasbrumjr@57417495/cloudkube-eks-terraform-pipeline-enb@1016370567`, followed by the corresponding `:ref:refs/heads/main` or `:environment:production` suffix. A custom subject template can change the format further. This repository predates that rollout, but its creation date alone does not prove its current subject setting. See [GitHub subject formats](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims). Inspect claim metadata without exposing a complete token.

## Plan Role: Exact Repository and Main Branch

This job has no GitHub environment. Use its observed branch subject:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "<OBSERVED_PLAN_SUB_FOR_THIS_REPOSITORY_AND_MAIN>",
        "token.actions.githubusercontent.com:repository_id": "1016370567",
        "token.actions.githubusercontent.com:repository_owner_id": "57417495",
        "token.actions.githubusercontent.com:ref": "refs/heads/main"
      }
    }
  }]
}
```

## Apply Role: Production Environment and Main Branch

An environment subject does not include a branch. Require `ref` separately:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "<OBSERVED_APPLY_SUB_FOR_THIS_REPOSITORY_AND_PRODUCTION>",
        "token.actions.githubusercontent.com:repository_id": "1016370567",
        "token.actions.githubusercontent.com:repository_owner_id": "57417495",
        "token.actions.githubusercontent.com:ref": "refs/heads/main",
        "token.actions.githubusercontent.com:environment": "production"
      }
    }
  }]
}
```

AWS currently documents GitHub `ref`, `environment`, and immutable ID conditions for role assumption. Its Access Analyzer explicitly recommends `ref` when an environment subject omits the branch. These claims are not available as session conditions after assumption. The GitHub AWS overview still contains a conflicting general note about custom claims; the examples above follow the current AWS condition-key reference and must be verified in the target account. Sources: [AWS GitHub condition keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html) and [Access Analyzer trust checks](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html).

## Operator Responsibilities and Limits

Configure the `production` environment's required reviewers and deployment branch rules separately in GitHub. Merely declaring `environment: production` in YAML does not configure those protections. The environment gate authorizes starting the apply job; it does **not** approve a particular Terraform plan, because that job generates its saved plan after the gate and then applies it. See [GitHub environment protection rules](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).

Trust policies only determine who can assume a role. The operator must separately review the plan role's resource-read permissions and the apply role's infrastructure permissions, including IAM/PassRole and KMS responsibilities. No deployment policy, permissions boundary, or bootstrap stack is supplied by this small change. Do not substitute administrator access to make an initial run pass. Backend state and lock permissions are described in [REMOTE_STATE.md](REMOTE_STATE.md).

The workflow runs cloud operations only on explicit manual requests from `main`; PR validation remains independent of AWS credentials. A future operator-authorized check must verify OIDC assumption, effective permissions, remote state/locking, and the actual plan before deployment. Those checks have not been performed in this repository-only review.
