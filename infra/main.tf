# ------------------------------------------------------------------------------
# VPC Module
# ------------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  project_name               = var.project_name
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
}

# ------------------------------------------------------------------------------
# EKS Module
# ------------------------------------------------------------------------------

module "eks" {
  source = "./modules/eks"

  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  private_subnet_ids   = module.vpc.private_subnet_ids
  eks_desired_capacity = var.eks_desired_capacity
  eks_max_size         = var.eks_max_size
  eks_min_size         = var.eks_min_size
  eks_instance_type    = var.eks_instance_type
  eks_ssh_key_name     = var.eks_ssh_key_name
}
