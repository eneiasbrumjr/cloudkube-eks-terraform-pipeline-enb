# Exercise the real child module to inspect its planned resource arguments.
mock_provider "aws" {
  override_during = plan
  source          = "./tests/mocks/aws"
}

mock_provider "tls" {
  override_during = plan
  source          = "./tests/mocks/tls"
}

variables {
  project_name                         = "mock-cloudkube"
  environment                          = "dev"
  vpc_id                               = "vpc-00000000000000000"
  subnet_ids                           = ["subnet-00000000000000001", "subnet-00000000000000002"]
  private_subnet_ids                   = ["subnet-00000000000000001", "subnet-00000000000000002"]
  eks_cluster_version                  = "1.36"
  eks_desired_capacity                 = 2
  eks_min_size                         = 1
  eks_max_size                         = 3
  eks_instance_types                   = ["t3.medium"]
  eks_disk_size                        = 20
  eks_ssh_key_name                     = ""
  enable_cluster_encryption            = true
  cluster_endpoint_public_access       = false
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = []
  cluster_enabled_log_types            = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  enable_irsa                          = true
  enable_spot_instances                = false
  create_cloudwatch_log_group          = true
  cloudwatch_log_group_retention_days  = 30
}

run "private_endpoint_and_al2023_nodes" {
  command = plan

  module {
    source = "./modules/eks"
  }

  assert {
    condition = (
      !aws_eks_cluster.main.vpc_config[0].endpoint_public_access &&
      aws_eks_cluster.main.vpc_config[0].endpoint_private_access
    )
    error_message = "The private-only selection must reach the EKS API configuration."
  }

  assert {
    condition = (
      aws_eks_cluster.main.version == "1.36" &&
      aws_eks_node_group.main.version == "1.36" &&
      aws_eks_node_group.main.ami_type == "AL2023_x86_64_STANDARD"
    )
    error_message = "The cluster and managed nodes must use the selected Kubernetes version with the explicit AL2023 AMI."
  }

  assert {
    condition = alltrue([
      data.aws_eks_addon_version.vpc_cni.kubernetes_version == "1.36",
      data.aws_eks_addon_version.kube_proxy.kubernetes_version == "1.36",
      data.aws_eks_addon_version.coredns.kubernetes_version == "1.36",
      data.aws_eks_addon_version.ebs_csi_driver.kubernetes_version == "1.36"
    ])
    error_message = "Every add-on lookup must use the cluster's selected Kubernetes version."
  }
}

run "explicit_public_access_and_version_override" {
  command = plan

  module {
    source = "./modules/eks"
  }

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = false
    cluster_endpoint_public_access_cidrs = ["198.51.100.0/24"]
    eks_cluster_version                  = "1.31"
  }

  assert {
    condition = (
      aws_eks_cluster.main.vpc_config[0].endpoint_public_access &&
      !aws_eks_cluster.main.vpc_config[0].endpoint_private_access &&
      aws_eks_cluster.main.vpc_config[0].public_access_cidrs == toset(["198.51.100.0/24"])
    )
    error_message = "Explicit public access must retain exactly the supplied trusted range."
  }

  assert {
    condition     = aws_eks_cluster.main.version == "1.31" && aws_eks_node_group.main.version == "1.31"
    error_message = "An explicit version override must reach both the cluster and managed nodes."
  }
}
