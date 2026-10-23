# ------------------------------------------------------------------------------
# KMS Key for EKS Cluster Encryption
# ------------------------------------------------------------------------------

locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

resource "aws_kms_key" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  description             = "KMS key for EKS cluster ${var.project_name}-${var.environment} encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-eks-kms"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_kms_alias" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group for EKS Control Plane Logs
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "eks" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  name              = "/aws/eks/${var.project_name}-${var.environment}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_days

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-eks-logs"
      Environment = var.environment
    },
    var.additional_tags
  )
}

# ------------------------------------------------------------------------------
# EKS Cluster IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-eks-cluster-role"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ------------------------------------------------------------------------------
# EKS Cluster
# ------------------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access ? var.cluster_endpoint_public_access_cidrs : null
  }

  # Enable control plane logging
  enabled_cluster_log_types = var.cluster_enabled_log_types

  # Enable secrets encryption with KMS
  dynamic "encryption_config" {
    for_each = var.enable_cluster_encryption ? [1] : []
    content {
      resources = ["secrets"]
      provider {
        key_arn = aws_kms_key.eks[0].arn
      }
    }
  }

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-eks-cluster"
      Environment = var.environment
    },
    var.additional_tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks
  ]
}

# ------------------------------------------------------------------------------
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# ------------------------------------------------------------------------------

data "tls_certificate" "eks" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-eks-oidc"
      Environment = var.environment
    },
    var.additional_tags
  )
}

# ------------------------------------------------------------------------------
# EKS Node Group IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-eks-node-role"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_ssm_managed_instance_core" {
  count = var.enable_ssm ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodes.name
}

moved {
  from = aws_iam_role_policy_attachment.eks_ssm_managed_instance_core
  to   = aws_iam_role_policy_attachment.eks_ssm_managed_instance_core[0]
}

# ------------------------------------------------------------------------------
# EKS Managed Node Group
# ------------------------------------------------------------------------------

resource "aws_eks_node_group" "main" {
  cluster_name           = aws_eks_cluster.main.name
  node_group_name_prefix = "${substr(local.cluster_name, 0, 32)}-ng-"
  node_role_arn          = aws_iam_role.eks_nodes.arn
  subnet_ids             = var.private_subnet_ids
  version                = var.eks_cluster_version

  scaling_config {
    desired_size = var.eks_desired_capacity
    max_size     = var.eks_max_size
    min_size     = var.eks_min_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  instance_types = var.eks_instance_types
  # AL2 images are unavailable for Kubernetes 1.33 and newer.
  ami_type      = "AL2023_x86_64_STANDARD"
  capacity_type = var.enable_spot_instances ? "SPOT" : "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.nodes.id
    version = tostring(aws_launch_template.nodes.latest_version)
  }

  labels = {
    Environment = var.environment
    NodeGroup   = "primary"
  }

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-node-group"
      Environment = var.environment
    },
    var.additional_tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
    aws_iam_role_policy_attachment.eks_ssm_managed_instance_core,
    aws_security_group_rule.cluster_egress,
    aws_security_group_rule.cluster_egress_https,
    aws_security_group_rule.cluster_egress_dns,
    aws_security_group_rule.cluster_ingress_nodes,
    aws_security_group_rule.nodes_egress,
    aws_security_group_rule.nodes_egress_cluster,
    aws_security_group_rule.nodes_egress_self,
    aws_security_group_rule.nodes_egress_s3,
    aws_security_group_rule.nodes_egress_dns,
    aws_security_group_rule.nodes_ingress_self,
    aws_security_group_rule.nodes_ingress_cluster,
    aws_security_group_rule.nodes_ingress_cluster_https,
    aws_security_group_rule.nodes_ingress_cluster_dns,
    aws_security_group_rule.endpoints_ingress_nodes,
    aws_security_group_rule.cluster_egress_webhooks,
    aws_security_group_rule.nodes_ingress_webhooks,
    aws_security_group_rule.nodes_egress_external,
    aws_security_group_rule.nodes_ingress_ssh,
    aws_vpc_endpoint.interface,
    aws_vpc_endpoint.s3,
  ]

  # Unique names permit replacement overlap. Existing workloads still need a
  # reviewed migration, capacity checks, and controlled draining.
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# ------------------------------------------------------------------------------
# EKS Add-ons
# ------------------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-vpc-cni"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-kube-proxy"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-coredns"
      Environment = var.environment
    },
    var.additional_tags
  )

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi_driver.version
  service_account_role_arn    = var.enable_irsa ? aws_iam_role.ebs_csi_driver[0].arn : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-ebs-csi-driver"
      Environment = var.environment
    },
    var.additional_tags
  )

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.ebs_csi_driver,
  ]
}

# ------------------------------------------------------------------------------
# IAM Role for EBS CSI Driver (IRSA)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_irsa ? 1 : 0

  name = "${var.project_name}-${var.environment}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-ebs-csi-driver"
      Environment = var.environment
    },
    var.additional_tags
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = var.enable_irsa ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}

# ------------------------------------------------------------------------------
# Data Sources for Add-on Versions
# ------------------------------------------------------------------------------

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.eks_cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.eks_cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.eks_cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.eks_cluster_version
  most_recent        = true
}
