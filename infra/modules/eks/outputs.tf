output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_id" {
  description = "The ID of the EKS cluster."
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster's API server."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "The platform version for the EKS cluster."
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_ca_certificate" {
  description = "The base64 encoded certificate data required to communicate with the cluster."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "The additional control-plane security group ID; this is not the cluster security group managed by EKS."
  value       = aws_security_group.eks_cluster.id
}

output "node_security_group_id" {
  description = "The security group explicitly attached to managed nodes by the launch template."
  value       = aws_security_group.eks_nodes.id
}

output "eks_managed_security_group_id" {
  description = "The EKS-created control-plane security group. Its rules are outside this module, and the node launch template does not attach this group."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_launch_template_id" {
  description = "The ID of the launch template used by the managed node group."
  value       = aws_launch_template.nodes.id
}

output "node_launch_template_version" {
  description = "The numeric launch template version selected for the managed node group."
  value       = aws_launch_template.nodes.latest_version
}

output "node_group_id" {
  description = "The ID of the EKS node group."
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "The ARN of the EKS node group."
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "The status of the EKS node group."
  value       = aws_eks_node_group.main.status
}

output "cluster_iam_role_arn" {
  description = "The ARN of the IAM role used by the EKS cluster."
  value       = aws_iam_role.eks_cluster.arn
}

output "node_iam_role_arn" {
  description = "The ARN of the IAM role used by the EKS nodes."
  value       = aws_iam_role.eks_nodes.arn
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for EKS."
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.eks[0].arn : null
}

output "oidc_provider_url" {
  description = "The URL of the OIDC Provider for EKS."
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.eks[0].url : null
}

output "cluster_encryption_key_arn" {
  description = "The ARN of the KMS key used for cluster encryption."
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null
}
