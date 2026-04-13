# ------------------------------------------------------------------------------
# Project Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "cloudkube-eks"

  validation {
    condition     = length(var.project_name) <= 32 && can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, max 32 characters."
  }
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, production)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "aws_region" {
  description = "The AWS region to deploy the resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region identifier."
  }
}

# ------------------------------------------------------------------------------
# VPC Variables
# ------------------------------------------------------------------------------

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidr_blocks" {
  description = "The CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition = length(var.public_subnet_cidr_blocks) >= 2 && alltrue([
      for cidr in var.public_subnet_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "Provide at least 2 valid public subnet CIDR blocks."
  }
}

variable "private_subnet_cidr_blocks" {
  description = "The CIDR blocks for the private subnets."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]

  validation {
    condition = length(var.private_subnet_cidr_blocks) >= 2 && alltrue([
      for cidr in var.private_subnet_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "Provide at least 2 valid private subnet CIDR blocks."
  }

  validation {
    condition     = length(var.private_subnet_cidr_blocks) >= length(var.public_subnet_cidr_blocks)
    error_message = "Private subnet count must be greater than or equal to the number of public subnets."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets. Set to false to reduce costs in dev environments."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ to reduce costs (not recommended for production)."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic analysis and security monitoring."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# EKS Cluster Variables
# ------------------------------------------------------------------------------

variable "eks_cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29"

  validation {
    condition     = contains(["1.29", "1.30", "1.31", "1.32", "1.33"], var.eks_cluster_version)
    error_message = "EKS cluster version must be one of the explicitly supported Kubernetes minor versions."
  }
}

variable "eks_desired_capacity" {
  description = "The desired number of nodes in the EKS cluster."
  type        = number
  default     = 2

  validation {
    condition     = var.eks_desired_capacity >= 1 && var.eks_desired_capacity <= 100
    error_message = "Desired capacity must be between 1 and 100."
  }
}

variable "eks_max_size" {
  description = "The maximum number of nodes in the EKS cluster."
  type        = number
  default     = 3

  validation {
    condition     = var.eks_max_size >= 1 && var.eks_max_size <= 100
    error_message = "Max size must be between 1 and 100."
  }
}

variable "eks_min_size" {
  description = "The minimum number of nodes in the EKS cluster."
  type        = number
  default     = 1

  validation {
    condition     = var.eks_min_size >= 1 && var.eks_min_size <= 100
    error_message = "Min size must be between 1 and 100."
  }
}

variable "eks_instance_types" {
  description = "The EC2 instance types for the EKS nodes. Multiple types enable mixed instance policies."
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]

  validation {
    condition     = length(var.eks_instance_types) > 0 && alltrue([for instance_type in var.eks_instance_types : trimspace(instance_type) != ""])
    error_message = "Provide at least one non-empty EC2 instance type."
  }
}

variable "eks_disk_size" {
  description = "The disk size in GB for the EKS worker nodes."
  type        = number
  default     = 20

  validation {
    condition     = var.eks_disk_size >= 20 && var.eks_disk_size <= 1000
    error_message = "Disk size must be between 20 and 1000 GB."
  }
}

variable "eks_ssh_key_name" {
  description = "The name of the EC2 key pair to use for SSH access to the nodes. Leave empty to disable SSH access."
  type        = string
  default     = ""
}

variable "enable_cluster_encryption" {
  description = "Enable encryption of Kubernetes secrets using AWS KMS."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the cluster endpoint. Set to false for private clusters."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API endpoint. Restrict to your IP for better security."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.cluster_endpoint_public_access_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Cluster endpoint public access CIDRs must be valid IPv4 CIDR blocks."
  }

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "Provide at least one CIDR block."
  }
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the cluster endpoint."
  type        = bool
  default     = true
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition = length(var.cluster_enabled_log_types) > 0 && alltrue([
      for log_type in var.cluster_enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Cluster log types must be valid EKS control plane log types."
  }
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA) for pod-level IAM permissions."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Cost Optimization Variables
# ------------------------------------------------------------------------------

variable "enable_spot_instances" {
  description = "Enable Spot Instances for cost optimization (not recommended for production critical workloads)."
  type        = bool
  default     = false
}

variable "create_cloudwatch_log_group" {
  description = "Create CloudWatch Log Group for EKS control plane logs."
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_days" {
  description = "Number of days to retain CloudWatch logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_group_retention_days)
    error_message = "Retention days must be a valid CloudWatch Logs retention period."
  }
}

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "additional_tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.additional_tags) : !startswith(key, "aws:")])
    error_message = "Additional tags must not use the reserved aws: prefix."
  }
}
