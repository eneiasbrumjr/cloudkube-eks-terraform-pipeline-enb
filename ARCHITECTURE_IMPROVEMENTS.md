# Repository Audit: 5 Key Architectural Improvements

## Overview
This document outlines 5 critical architectural improvements for the CloudKube EKS Terraform Pipeline, focusing on production-readiness, security, and operational excellence.

---

## 1. Remote State Backend Migration (S3 + DynamoDB)

### Current State
```hcl
# infra/backend.tf - Currently commented out
# Uses local state (terraform.tfstate)
```

### Recommended Implementation

**Step 1: Create S3 Backend Infrastructure**
```hcl
# infra-bootstrap/main.tf (separate directory)
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "your-company-terraform-state-eks"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-state-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "Terraform State Locks"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# Output for use in main project
output "backend_config" {
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "eks/terraform.tfstate"
        region         = "${aws_s3_bucket.terraform_state.region}"
        encrypt        = true
        kms_key_id     = "${aws_kms_key.terraform_state.arn}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
      }
    }
  EOT
  description = "Backend configuration for main EKS project"
}
```

**Step 2: Update Main Backend Configuration**
```hcl
# infra/backend.tf - Updated
terraform {
  backend "s3" {
    bucket         = "your-company-terraform-state-eks"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID"
    dynamodb_table = "terraform-state-locks"

    # Workspace support
    workspace_key_prefix = "workspaces"
  }
}
```

**Migration Steps**
```bash
# 1. Create backend infrastructure
cd infra-bootstrap
terraform init
terraform apply

# 2. Migrate existing state
cd ../infra
terraform init -migrate-state

# 3. Verify migration
terraform state list
aws s3 ls s3://your-company-terraform-state-eks/eks/
```

**Benefits**
- State locking prevents concurrent modifications
- Versioning enables state recovery
- Encryption protects sensitive data
- Team collaboration enabled
- Workspace support for multi-environment

---

## 2. Enhanced IRSA (IAM Roles for Service Accounts) Implementation

### Current State
```hcl
# Already implemented for EBS CSI Driver
# Missing: AWS Load Balancer Controller, External DNS, Cluster Autoscaler
```

### Recommended Additions

**AWS Load Balancer Controller IRSA**
```hcl
# infra/modules/eks/irsa-alb-controller.tf
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  count = var.enable_irsa && var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_irsa && var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.project_name}-${var.environment}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role[0].json

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-alb-controller"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_irsa && var.enable_aws_load_balancer_controller ? 1 : 0

  name        = "${var.project_name}-${var.environment}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_irsa && var.enable_aws_load_balancer_controller ? 1 : 0

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = var.enable_irsa && var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}
```

**Cluster Autoscaler IRSA**
```hcl
# infra/modules/eks/irsa-cluster-autoscaler.tf
resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_irsa && var.enable_cluster_autoscaler ? 1 : 0

  name = "${var.project_name}-${var.environment}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" : "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-cluster-autoscaler"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_irsa && var.enable_cluster_autoscaler ? 1 : 0

  name        = "${var.project_name}-${var.environment}-ClusterAutoscalerPolicy"
  description = "IAM policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enable_irsa && var.enable_cluster_autoscaler ? 1 : 0

  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}
```

**Benefits**
- No long-lived IAM credentials on nodes
- Fine-grained permissions per workload
- Automatic credential rotation
- Audit trail via CloudTrail
- Follows AWS security best practices

---

## 3. OIDC Configuration with GitHub Actions

### Current State
```yaml
# .github/workflows - Uses long-lived AWS credentials
aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Recommended Implementation

**Step 1: Create GitHub OIDC Provider**
```hcl
# infra-bootstrap/github-oidc.tf
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Name        = "GitHub Actions OIDC"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role" "github_actions_eks" {
  name = "GitHubActions-EKS-Terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:YOUR-ORG/cloudkube-eks-terraform-pipeline-enb:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_eks" {
  role       = aws_iam_role.github_actions_eks.name
  policy_arn = aws_iam_policy.terraform_eks_deploy.arn
}

resource "aws_iam_policy" "terraform_eks_deploy" {
  name        = "TerraformEKSDeploy"
  description = "Policy for GitHub Actions to deploy EKS via Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:*",
          "iam:*",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_eks.arn
  description = "ARN to use in GitHub Actions workflow"
}
```

**Step 2: Update GitHub Actions Workflow**
```yaml
# .github/workflows/terraform-eks-pipeline.yml
name: "Terraform EKS Pipeline with OIDC"

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read
  pull-requests: write

env:
  TF_VERSION: "1.5.0"
  AWS_REGION: "us-east-1"

jobs:
  terraform:
    name: "Terraform"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./infra

    steps:
      - name: "Checkout"
        uses: actions/checkout@v4

      - name: "Configure AWS Credentials via OIDC"
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          role-session-name: GitHubActions-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: "Verify AWS Identity"
        run: aws sts get-caller-identity

      - name: "Setup Terraform"
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: "Terraform Init"
        run: terraform init

      - name: "Terraform Validate"
        run: terraform validate

      - name: "Terraform Plan"
        if: github.event_name == 'pull_request'
        run: terraform plan -no-color

      - name: "Terraform Apply"
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve
```

**Benefits**
- No long-lived credentials stored in GitHub
- Automatic credential rotation
- Fine-grained access control
- Audit trail in CloudTrail
- Eliminates credential leakage risk

---

## 4. Multi-Environment Workspace Strategy

### Current State
```hcl
# Single environment, no workspace support
```

### Recommended Implementation

**Terraform Workspaces Configuration**
```hcl
# infra/backend.tf
terraform {
  backend "s3" {
    bucket               = "your-company-terraform-state-eks"
    key                  = "eks/terraform.tfstate"
    region               = "us-east-1"
    encrypt              = true
    kms_key_id           = "arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID"
    dynamodb_table       = "terraform-state-locks"
    workspace_key_prefix = "workspaces"
  }
}

locals {
  workspace_config = {
    dev = {
      eks_cluster_version         = "1.28"
      eks_desired_capacity        = 1
      eks_max_size                = 2
      eks_min_size                = 1
      eks_instance_types          = ["t3.small"]
      enable_nat_gateway          = false
      enable_spot_instances       = true
      cloudwatch_retention_days   = 1
    }
    staging = {
      eks_cluster_version         = "1.28"
      eks_desired_capacity        = 2
      eks_max_size                = 3
      eks_min_size                = 1
      eks_instance_types          = ["t3.medium"]
      enable_nat_gateway          = true
      single_nat_gateway          = true
      enable_spot_instances       = false
      cloudwatch_retention_days   = 7
    }
    production = {
      eks_cluster_version         = "1.28"
      eks_desired_capacity        = 3
      eks_max_size                = 10
      eks_min_size                = 3
      eks_instance_types          = ["t3.large", "t3a.large"]
      enable_nat_gateway          = true
      single_nat_gateway          = false
      enable_spot_instances       = false
      cloudwatch_retention_days   = 30
    }
  }

  current_config = local.workspace_config[terraform.workspace]
}

# infra/main.tf - Use workspace config
module "eks" {
  source = "./modules/eks"

  eks_cluster_version         = local.current_config.eks_cluster_version
  eks_desired_capacity        = local.current_config.eks_desired_capacity
  eks_max_size                = local.current_config.eks_max_size
  eks_min_size                = local.current_config.eks_min_size
  eks_instance_types          = local.current_config.eks_instance_types
  cloudwatch_retention_days   = local.current_config.cloudwatch_retention_days

  # ... other variables
}
```

**Usage**
```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new production

# Deploy to dev
terraform workspace select dev
terraform apply

# Deploy to production
terraform workspace select production
terraform apply

# List workspaces
terraform workspace list

# Show current workspace
terraform workspace show
```

**Benefits**
- Single codebase for all environments
- Consistent configuration
- Easy environment switching
- Isolated state per environment
- Cost optimization per environment

---

## 5. Enhanced Security: Pod Security Standards & Network Policies

### Current State
```hcl
# Missing: Pod Security Standards enforcement
# Missing: Network Policies
```

### Recommended Implementation

**Pod Security Standards**
```hcl
# infra/modules/eks/pod-security-standards.tf
resource "null_resource" "apply_pod_security_standards" {
  depends_on = [aws_eks_cluster.main]

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}

      # Apply PSS to kube-system namespace
      kubectl label namespace kube-system \
        pod-security.kubernetes.io/enforce=privileged \
        pod-security.kubernetes.io/audit=privileged \
        pod-security.kubernetes.io/warn=privileged \
        --overwrite

      # Create restricted namespace template
      cat <<EOF | kubectl apply -f -
      apiVersion: v1
      kind: Namespace
      metadata:
        name: production
        labels:
          pod-security.kubernetes.io/enforce: restricted
          pod-security.kubernetes.io/audit: restricted
          pod-security.kubernetes.io/warn: restricted
      EOF
    EOT
  }
}
```

**Default Network Policy**
```hcl
# infra/modules/eks/network-policies.tf
resource "null_resource" "apply_network_policies" {
  depends_on = [aws_eks_cluster.main, aws_eks_node_group.main]

  provisioner "local-exec" {
    command = <<-EOT
      # Deny all ingress by default
      cat <<EOF | kubectl apply -f -
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      metadata:
        name: deny-all-ingress
        namespace: default
      spec:
        podSelector: {}
        policyTypes:
        - Ingress
      ---
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      metadata:
        name: allow-dns
        namespace: default
      spec:
        podSelector: {}
        policyTypes:
        - Egress
        egress:
        - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
          ports:
          - protocol: UDP
            port: 53
      EOF
    EOT
  }
}
```

**Kubernetes Resource Quotas**
```yaml
# infra/kubernetes-manifests/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    persistentvolumeclaims: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: production
spec:
  limits:
  - max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "200m"
      memory: "256Mi"
    type: Container
```

**Benefits**
- Enforced security standards
- Network segmentation
- Resource limits prevent noisy neighbors
- Compliance with CIS Kubernetes Benchmark
- Defense-in-depth security

---

## Implementation Priority

1. **High Priority**: Remote State Backend (enables team collaboration)
2. **High Priority**: OIDC with GitHub Actions (eliminates credential risk)
3. **Medium Priority**: Enhanced IRSA (security best practice)
4. **Medium Priority**: Multi-Environment Workspaces (operational efficiency)
5. **Medium Priority**: Pod Security Standards (compliance requirement)

---

## Migration Checklist

- [ ] Create backend infrastructure (S3 + DynamoDB)
- [ ] Migrate state from local to remote
- [ ] Implement GitHub OIDC provider
- [ ] Update GitHub Actions workflow
- [ ] Add IRSA roles for add-ons
- [ ] Configure workspace strategy
- [ ] Apply Pod Security Standards
- [ ] Deploy Network Policies
- [ ] Test in dev environment
- [ ] Document changes
- [ ] Update README
- [ ] Train team on new workflow

---

## Cost Impact

| Improvement | Monthly Cost | Notes |
|-------------|--------------|-------|
| S3 + DynamoDB Backend | ~$1-2 | Minimal, state files are small |
| GitHub OIDC | $0 | No additional cost |
| Enhanced IRSA | $0 | No additional cost |
| Workspaces | $0 | Organizational only |
| Network Policies | $0 | Native Kubernetes feature |

**Total Additional Cost**: ~$1-2/month

---

## References

- [Terraform S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [EKS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
