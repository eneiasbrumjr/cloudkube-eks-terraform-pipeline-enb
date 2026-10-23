check "node_group_scaling" {
  assert {
    condition     = var.eks_min_size <= var.eks_desired_capacity && var.eks_desired_capacity <= var.eks_max_size
    error_message = "Node group sizing must satisfy eks_min_size <= eks_desired_capacity <= eks_max_size."
  }
}
