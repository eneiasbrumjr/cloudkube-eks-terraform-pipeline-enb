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

  project_name                           = var.project_name
  environment                            = var.environment
  aws_region                             = var.aws_region
  vpc_id                                 = module.vpc.vpc_id
  vpc_cidr_block                         = module.vpc.vpc_cidr_block
  private_route_table_ids                = module.vpc.private_route_table_ids
  subnet_ids                             = module.vpc.private_subnet_ids
  private_subnet_ids                     = module.vpc.private_subnet_ids
  eks_cluster_version                    = var.eks_cluster_version
  eks_desired_capacity                   = var.eks_desired_capacity
  eks_max_size                           = var.eks_max_size
  eks_min_size                           = var.eks_min_size
  eks_instance_types                     = var.eks_instance_types
  eks_disk_size                          = var.eks_disk_size
  eks_ssh_key_name                       = var.eks_ssh_key_name
  ssh_source_security_group_ids          = var.eks_ssh_source_security_group_ids
  api_admin_security_group_ids           = var.eks_api_admin_security_group_ids
  control_plane_webhook_ports            = var.eks_control_plane_webhook_ports
  external_https_cidrs                   = var.eks_external_https_cidrs
  enable_ssm                             = var.eks_enable_ssm
  additional_interface_endpoint_services = var.eks_additional_interface_endpoint_services
  s3_read_bucket_arns                    = var.eks_s3_read_bucket_arns
  enable_cluster_encryption              = var.enable_cluster_encryption
  cluster_endpoint_public_access         = var.cluster_endpoint_public_access
  cluster_endpoint_private_access        = var.cluster_endpoint_private_access
  cluster_enabled_log_types              = var.cluster_enabled_log_types
  enable_irsa                            = var.enable_irsa
  cluster_endpoint_public_access_cidrs   = var.cluster_endpoint_public_access_cidrs
  enable_spot_instances                  = var.enable_spot_instances
  create_cloudwatch_log_group            = var.create_cloudwatch_log_group
  cloudwatch_log_group_retention_days    = var.cloudwatch_log_group_retention_days
  additional_tags                        = var.additional_tags
}
