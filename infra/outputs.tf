# ------------------------------------------------------------------------------
# EKS Cluster Outputs
# ------------------------------------------------------------------------------

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_id" {
  description = "The ID of the EKS cluster."
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster's API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  value       = module.eks.cluster_version
}

output "cluster_ca_certificate" {
  description = "The base64 encoded certificate data required to communicate with the cluster."
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "The security group ID attached to the EKS cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "The security group ID attached to the EKS nodes."
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for EKS (for IRSA)."
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl to connect to the EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ------------------------------------------------------------------------------
# VPC Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "The IDs of the NAT Gateways."
  value       = module.vpc.nat_gateway_ids
}
