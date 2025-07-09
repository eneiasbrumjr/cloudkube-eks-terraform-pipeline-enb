variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs to use for the EKS cluster."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs to use for the EKS node group."
  type        = list(string)
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

variable "eks_instance_type" {
  description = "The EC2 instance type for the EKS nodes."
  type        = string
}

variable "eks_ssh_key_name" {
  description = "The name of the EC2 key pair to use for SSH access to the nodes."
  type        = string
}
