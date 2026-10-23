# Every run is a mock plan. No AWS credentials or live infrastructure are used.
mock_provider "aws" {
  override_during = plan
  source          = "./tests/mocks/aws"
}

mock_provider "tls" {
  override_during = plan
  source          = "./tests/mocks/tls"
}

run "hardened_defaults" {
  command = plan

  assert {
    condition     = !var.cluster_endpoint_public_access && var.cluster_endpoint_private_access
    error_message = "The root interface must default to private API access only."
  }

  assert {
    condition     = length(var.cluster_endpoint_public_access_cidrs) == 0
    error_message = "Public endpoint access must require an explicit allowlist."
  }

  assert {
    condition     = output.cluster_version == "1.36"
    error_message = "The default Kubernetes version must reach the planned EKS cluster."
  }
}

run "explicit_public_access_with_trusted_range" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = false
    cluster_endpoint_public_access_cidrs = ["198.51.100.0/24"]
  }
}

run "earlier_available_version_remains_configurable" {
  command = plan

  variables {
    eks_cluster_version = "1.31"
  }

  assert {
    condition     = output.cluster_version == "1.31"
    error_message = "An explicitly selected supported migration version must reach the cluster."
  }
}

run "reject_endpoint_with_no_access_mode" {
  command = plan

  variables {
    cluster_endpoint_public_access  = false
    cluster_endpoint_private_access = false
  }

  expect_failures = [var.cluster_endpoint_public_access]
}

run "reject_public_endpoint_without_allowlist" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = []
  }

  expect_failures = [var.cluster_endpoint_public_access]
}

run "reject_unrestricted_ipv4" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}

run "reject_noncanonical_unrestricted_ipv4" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["10.0.0.0/0"]
  }

  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}

run "reject_ipv6_endpoint_range" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["2001:db8::/32"]
  }

  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}

run "reject_malformed_endpoint_range" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["198.51.100.0/33"]
  }

  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}

run "reject_removed_kubernetes_version" {
  command = plan

  variables {
    eks_cluster_version = "1.29"
  }

  expect_failures = [var.eks_cluster_version]
}
