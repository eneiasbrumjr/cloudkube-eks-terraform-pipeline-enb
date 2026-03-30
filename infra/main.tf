# ------------------------------------------------------------------------------
# VPC Module
# ------------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  project_name               = var.project_name
  environment                = var.environment
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  enable_nat_gateway         = var.enable_nat_gateway
  single_nat_gateway         = var.single_nat_gateway
  enable_vpc_flow_logs       = var.enable_vpc_flow_logs
  additional_tags            = var.additional_tags
}

# ------------------------------------------------------------------------------
# EKS Module
# ------------------------------------------------------------------------------

module "eks" {
  source = "./modules/eks"

  project_name                        = var.project_name
  environment                         = var.environment
  vpc_id                              = module.vpc.vpc_id
  subnet_ids                          = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  private_subnet_ids                  = module.vpc.private_subnet_ids
  eks_cluster_version                 = var.eks_cluster_version
  eks_desired_capacity                = var.eks_desired_capacity
  eks_max_size                        = var.eks_max_size
  eks_min_size                        = var.eks_min_size
  eks_instance_types                  = var.eks_instance_types
  eks_disk_size                       = var.eks_disk_size
  eks_ssh_key_name                    = var.eks_ssh_key_name
  enable_cluster_encryption           = var.enable_cluster_encryption
  cluster_endpoint_public_access      = var.cluster_endpoint_public_access
  cluster_endpoint_private_access     = var.cluster_endpoint_private_access
  cluster_enabled_log_types           = var.cluster_enabled_log_types
  enable_irsa                         = var.enable_irsa
  allowed_cidr_blocks                 = var.allowed_cidr_blocks
  enable_spot_instances               = var.enable_spot_instances
  spot_instance_pools                 = var.spot_instance_pools
  create_cloudwatch_log_group         = var.create_cloudwatch_log_group
  cloudwatch_log_group_retention_days = var.cloudwatch_log_group_retention_days
  additional_tags                     = var.additional_tags
}
