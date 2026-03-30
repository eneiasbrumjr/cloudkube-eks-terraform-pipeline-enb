variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, production)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs to use for the EKS cluster control plane."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs to use for the EKS node group."
  type        = list(string)
}

variable "eks_cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
}

variable "eks_desired_capacity" {
  description = "The desired number of nodes in the EKS cluster."
  type        = number
}

variable "eks_max_size" {
  description = "The maximum number of nodes in the EKS cluster."
  type        = number
}

variable "eks_min_size" {
  description = "The minimum number of nodes in the EKS cluster."
  type        = number
}

variable "eks_instance_types" {
  description = "The EC2 instance types for the EKS nodes."
  type        = list(string)
}

variable "eks_disk_size" {
  description = "The disk size in GB for the EKS worker nodes."
  type        = number
}

variable "eks_ssh_key_name" {
  description = "The name of the EC2 key pair to use for SSH access to the nodes."
  type        = string
}

variable "enable_cluster_encryption" {
  description = "Enable encryption of Kubernetes secrets using AWS KMS."
  type        = bool
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the cluster endpoint."
  type        = bool
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the cluster endpoint."
  type        = bool
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable."
  type        = list(string)
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)."
  type        = bool
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the EKS cluster API endpoint."
  type        = list(string)
}

variable "enable_spot_instances" {
  description = "Enable Spot Instances for cost optimization."
  type        = bool
}

variable "spot_instance_pools" {
  description = "Number of Spot Instance pools to use."
  type        = number
}

variable "create_cloudwatch_log_group" {
  description = "Create CloudWatch Log Group for EKS control plane logs."
  type        = bool
}

variable "cloudwatch_log_group_retention_days" {
  description = "Number of days to retain CloudWatch logs."
  type        = number
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
