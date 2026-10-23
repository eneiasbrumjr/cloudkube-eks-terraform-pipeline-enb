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
    condition     = can(cidrnetmask(var.vpc_cidr_block))
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
  description = "Opt in to NAT routing for explicitly allowed external HTTPS destinations. Private AWS endpoints are always created."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ to reduce costs (not recommended for production)."
  type        = bool
  default     = true

  validation {
    condition     = !var.enable_nat_gateway || var.single_nat_gateway || length(var.public_subnet_cidr_blocks) == length(var.private_subnet_cidr_blocks)
    error_message = "Per-AZ NAT requires matching public/private subnet counts so each private subnet has a NAT in its AZ."
  }
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
  description = "Kubernetes minor version for the cluster and nodes. Availability reviewed on 2026-10-23; older allowed versions can incur extended-support charges."
  type        = string
  default     = "1.36"

  validation {
    condition     = contains(["1.31", "1.32", "1.33", "1.34", "1.35", "1.36", "1.37"], var.eks_cluster_version)
    error_message = "Select an EKS minor version available on 2026-10-23: 1.31 through 1.37. Prefer standard support (1.34 through 1.37); review current regional availability before deployment."
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
  description = "The x86_64 EC2 instance types for the AL2023 EKS nodes. Multiple types enable mixed instance policies."
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
  description = "Opt in to public API access with explicit, restricted IPv4 CIDRs. Private access is enabled by default."
  type        = bool
  default     = false

  validation {
    condition     = var.cluster_endpoint_public_access || var.cluster_endpoint_private_access
    error_message = "At least one EKS cluster endpoint access mode must be enabled."
  }

  validation {
    condition     = !var.cluster_endpoint_public_access || length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "Provide at least one restricted IPv4 CIDR block when public endpoint access is enabled."
  }
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Trusted IPv4 CIDR blocks for the optional public API endpoint. Empty when disabled; /0 and IPv6 ranges are not accepted."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.cluster_endpoint_public_access_cidrs : try(cidrnetmask(cidr) != "0.0.0.0", false)
    ])
    error_message = "Cluster endpoint CIDRs must be valid, restricted IPv4 ranges. Unrestricted /0 ranges and IPv6 are not accepted by this IPv4 baseline."
  }

  validation {
    condition     = try(sum(concat([0], [for cidr in var.cluster_endpoint_public_access_cidrs : pow(2, 32 - tonumber(split("/", cidr)[1]))])) < pow(2, 32), false)
    error_message = "The combined CIDR address count must be smaller than the IPv4 address space; splitting unrestricted access into multiple ranges is not accepted."
  }
}

variable "cluster_endpoint_private_access" {
  description = "Private API access must remain enabled for the restricted node network."
  type        = bool
  default     = true

  validation {
    condition     = var.cluster_endpoint_private_access
    error_message = "Private API access is required: node egress reaches the control-plane security group over the VPC."
  }
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
  description = "IRSA must remain enabled for the EBS CSI add-on installed by this module."
  type        = bool
  default     = true

  validation {
    condition     = var.enable_irsa
    error_message = "IRSA is required for the installed EBS CSI controller; ordinary pods do not inherit the node role through IMDS."
  }
}

# ------------------------------------------------------------------------------
# Restricted Node Network
# ------------------------------------------------------------------------------

variable "eks_enable_ssm" {
  description = "Opt in to the SSM node IAM policy plus ssm and ssmmessages private endpoints. Agent readiness and extra S3/logging permissions require separate verification."
  type        = bool
  default     = false
}

variable "eks_additional_interface_endpoint_services" {
  description = "Additional regional AWS interface endpoint suffixes, for example logs or secretsmanager. Each service incurs an endpoint charge in every private subnet/AZ."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for service in var.eks_additional_interface_endpoint_services : can(regex("^[a-z][a-z0-9-]*(\\.[a-z0-9-]+)*$", service)) && service != "s3"
    ])
    error_message = "Use AWS interface service suffixes such as logs or eks-auth. S3 already uses a gateway endpoint. Check regional service availability before deployment."
  }
}

variable "eks_s3_read_bucket_arns" {
  description = "Additional commercial-partition S3 bucket ARNs allowed s3:GetObject through the gateway endpoint; IAM/bucket policies must also allow access. ECR layer reads are included automatically."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.eks_s3_read_bucket_arns : can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", arn))
    ])
    error_message = "Provide explicit S3 bucket ARNs without object paths, wildcards, or non-commercial partitions."
  }
}

variable "eks_api_admin_security_group_ids" {
  description = "Existing source security groups authorized for TCP 443 to the private API. Routing and Kubernetes authentication are configured separately."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.eks_api_admin_security_group_ids : can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "Private API administration sources must be valid security group IDs."
  }
}

variable "eks_ssh_source_security_group_ids" {
  description = "Existing source security groups authorized for TCP 22. Set only together with eks_ssh_key_name; empty by default."
  type        = set(string)
  default     = []

  validation {
    condition     = (length(var.eks_ssh_source_security_group_ids) == 0) == (trimspace(var.eks_ssh_key_name) == "")
    error_message = "SSH requires both a non-empty eks_ssh_key_name and explicit source security group IDs, or neither."
  }

  validation {
    condition     = alltrue([for id in var.eks_ssh_source_security_group_ids : can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "SSH sources must be valid security group IDs."
  }
}

variable "eks_control_plane_webhook_ports" {
  description = "Additional explicit TCP ports from the control plane to node-hosted webhooks; 443, 10250 and DNS 53 are already configured."
  type        = set(number)
  default     = []

  validation {
    condition     = alltrue([for port in var.eks_control_plane_webhook_ports : port >= 1 && port <= 65535 && floor(port) == port && !contains([53, 443, 10250], port)])
    error_message = "Webhook ports must be integers from 1 through 65535, excluding the existing ports 53, 443 and 10250."
  }
}

variable "eks_external_https_cidrs" {
  description = "Explicit external IPv4 destinations allowed on TCP 443; requires enable_nat_gateway. Empty by default. Review destinations and routing before use."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.eks_external_https_cidrs : try(cidrnetmask(cidr) != "0.0.0.0", false)])
    error_message = "External HTTPS destinations must be valid restricted IPv4 CIDRs; /0 and IPv6 ranges are not accepted."
  }

  validation {
    condition     = try(sum(concat([0], [for cidr in var.eks_external_https_cidrs : pow(2, 32 - tonumber(split("/", cidr)[1]))])) < pow(2, 32), false)
    error_message = "The combined destination address count must be smaller than the IPv4 address space; splitting unrestricted access into multiple ranges is not accepted."
  }

  validation {
    condition     = length(var.eks_external_https_cidrs) == 0 || var.enable_nat_gateway
    error_message = "Explicit external HTTPS destinations require enable_nat_gateway = true for private subnet routing."
  }
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
