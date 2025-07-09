# ------------------------------------------------------------------------------
# Project Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "cloudkube-eks"
}

variable "aws_region" {
  description = "The AWS region to deploy the resources."
  type        = string
  default     = "us-east-1"
}

# ------------------------------------------------------------------------------
# VPC Variables
# ------------------------------------------------------------------------------

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  description = "The CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr_blocks" {
  description = "The CIDR blocks for the private subnets."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# ------------------------------------------------------------------------------
# EKS Cluster Variables
# ------------------------------------------------------------------------------

variable "eks_desired_capacity" {
  description = "The desired number of nodes in the EKS cluster."
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "The maximum number of nodes in the EKS cluster."
  type        = number
  default     = 3
}

variable "eks_min_size" {
  description = "The minimum number of nodes in the EKS cluster."
  type        = number
  default     = 1
}

variable "eks_instance_type" {
  description = "The EC2 instance type for the EKS nodes."
  type        = string
  default     = "t3.medium"
}

variable "eks_ssh_key_name" {
  description = "The name of the EC2 key pair to use for SSH access to the nodes."
  type        = string
  default     = ""
}
