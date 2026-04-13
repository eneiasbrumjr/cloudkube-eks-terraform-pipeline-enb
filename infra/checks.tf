check "node_group_scaling" {
  assert {
    condition     = var.eks_min_size <= var.eks_desired_capacity && var.eks_desired_capacity <= var.eks_max_size
    error_message = "Node group sizing must satisfy eks_min_size <= eks_desired_capacity <= eks_max_size."
  }
}

check "cluster_endpoint_access" {
  assert {
    condition     = var.cluster_endpoint_private_access || var.cluster_endpoint_public_access
    error_message = "At least one EKS cluster endpoint access mode must be enabled."
  }

  assert {
    condition     = !var.cluster_endpoint_public_access || length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "Provide at least one CIDR block when public endpoint access is enabled."
  }

  assert {
    condition     = var.environment != "production" || !contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0")
    error_message = "Do not allow 0.0.0.0/0 to access the EKS public endpoint in production."
  }
}
