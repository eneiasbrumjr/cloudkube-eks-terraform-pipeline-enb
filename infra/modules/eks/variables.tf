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
  description = "Opt in to public API access with explicit, restricted IPv4 CIDRs. Private access is enabled by default."
  type        = bool

  validation {
    condition     = var.cluster_endpoint_public_access || var.cluster_endpoint_private_access
    error_message = "At least one EKS cluster endpoint access mode must be enabled."
  }

  validation {
    condition     = !var.cluster_endpoint_public_access || length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "Provide at least one restricted IPv4 CIDR block when public endpoint access is enabled."
  }
}

variable "cluster_endpoint_private_access" {
  description = "Private API access must remain enabled for the restricted node network."
  type        = bool

  validation {
    condition     = var.cluster_endpoint_private_access
    error_message = "Private API access is required: node egress reaches the control-plane security group over the VPC."
  }
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable."
  type        = list(string)
}

variable "enable_irsa" {
  description = "IRSA must remain enabled for the EBS CSI add-on installed by this module."
  type        = bool

  validation {
    condition     = var.enable_irsa
    error_message = "IRSA is required for the installed EBS CSI controller; ordinary pods do not inherit the node role through IMDS."
  }
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Trusted IPv4 CIDR blocks for the optional public API endpoint. Empty when disabled; /0 and IPv6 ranges are not accepted."
  type        = list(string)

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

variable "enable_spot_instances" {
  description = "Enable Spot Instances for cost optimization."
  type        = bool
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

# Network inputs for the private AWS service paths.
variable "aws_region" {
  description = "Commercial AWS region for the private service endpoints and ECR layer bucket. Must match the provider region."
  type        = string
}

variable "vpc_cidr_block" {
  description = "Primary IPv4 CIDR of the VPC, used to document its AmazonProvidedDNS resolver address."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "The EKS network requires an IPv4 VPC CIDR."
  }
}

variable "private_route_table_ids" {
  description = "Route tables for every private node subnet; the S3 gateway endpoint is associated with these tables."
  type        = list(string)

  validation {
    condition     = length(var.private_route_table_ids) > 0
    error_message = "Provide the route tables used by the private node subnets."
  }
}

variable "enable_ssm" {
  description = "Opt in to the SSM node IAM policy plus ssm and ssmmessages private endpoints. Agent readiness and extra S3/logging permissions require separate verification."
  type        = bool
  default     = false
}

variable "additional_interface_endpoint_services" {
  description = "Additional regional AWS interface endpoint suffixes, for example logs or secretsmanager. Each service incurs an endpoint charge in every private subnet/AZ."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for service in var.additional_interface_endpoint_services : can(regex("^[a-z][a-z0-9-]*(\\.[a-z0-9-]+)*$", service)) && service != "s3"
    ])
    error_message = "Use AWS interface service suffixes such as logs or eks-auth. S3 already uses a gateway endpoint. Check regional service availability before deployment."
  }
}

variable "s3_read_bucket_arns" {
  description = "Additional commercial-partition S3 bucket ARNs allowed s3:GetObject through the gateway endpoint; IAM/bucket policies must also allow access. ECR layer reads are included automatically."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.s3_read_bucket_arns : can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", arn))
    ])
    error_message = "Provide explicit S3 bucket ARNs without object paths, wildcards, or non-commercial partitions."
  }
}

variable "api_admin_security_group_ids" {
  description = "Existing source security groups authorized for TCP 443 to the private API. Routing and Kubernetes authentication are configured separately."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.api_admin_security_group_ids : can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "Private API administration sources must be valid security group IDs."
  }
}

variable "ssh_source_security_group_ids" {
  description = "Existing source security groups authorized for TCP 22. Set only together with eks_ssh_key_name; empty by default."
  type        = set(string)
  default     = []

  validation {
    condition     = (length(var.ssh_source_security_group_ids) == 0) == (trimspace(var.eks_ssh_key_name) == "")
    error_message = "SSH requires both a non-empty eks_ssh_key_name and explicit source security group IDs, or neither."
  }

  validation {
    condition     = alltrue([for id in var.ssh_source_security_group_ids : can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "SSH sources must be valid security group IDs."
  }
}

variable "control_plane_webhook_ports" {
  description = "Additional explicit TCP ports from the control plane to node-hosted webhooks; 443, 10250 and DNS 53 are already configured."
  type        = set(number)
  default     = []

  validation {
    condition     = alltrue([for port in var.control_plane_webhook_ports : port >= 1 && port <= 65535 && floor(port) == port && !contains([53, 443, 10250], port)])
    error_message = "Webhook ports must be integers from 1 through 65535, excluding the existing ports 53, 443 and 10250."
  }
}

variable "external_https_cidrs" {
  description = "Explicit external IPv4 destinations allowed on TCP 443; the caller must provide NAT routing. Empty by default. Review destinations and routing before use."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.external_https_cidrs : try(cidrnetmask(cidr) != "0.0.0.0", false)])
    error_message = "External HTTPS destinations must be valid restricted IPv4 CIDRs; /0 and IPv6 ranges are not accepted."
  }

  validation {
    condition     = try(sum(concat([0], [for cidr in var.external_https_cidrs : pow(2, 32 - tonumber(split("/", cidr)[1]))])) < pow(2, 32), false)
    error_message = "The combined destination address count must be smaller than the IPv4 address space; splitting unrestricted access into multiple ranges is not accepted."
  }

}
