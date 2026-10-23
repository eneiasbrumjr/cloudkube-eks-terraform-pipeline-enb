variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, production)."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidr_blocks" {
  description = "The CIDR blocks for the public subnets."
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "The CIDR blocks for the private subnets."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Opt in to NAT Gateway routing for private subnets. The root EKS configuration uses private endpoints by default."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_nat_gateway || var.single_nat_gateway || length(var.public_subnet_cidr_blocks) == length(var.private_subnet_cidr_blocks)
    error_message = "Per-AZ NAT requires matching public/private subnet counts so route-table indexing stays in the same AZ."
  }
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic analysis."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
