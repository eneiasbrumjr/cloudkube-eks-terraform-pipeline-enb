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

  assert {
    condition     = !var.enable_nat_gateway && length(output.nat_gateway_ids) == 0
    error_message = "The private-endpoint baseline must not create NAT gateways by default."
  }
}

run "explicit_public_access_with_trusted_range" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = true
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

  # The public-access validation depends on the private variable, so Terraform
  # stops at this required-private guard before evaluating that dependent check.
  expect_failures = [var.cluster_endpoint_private_access]
}

run "reject_public_only_endpoint" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = false
    cluster_endpoint_public_access_cidrs = ["198.51.100.0/24"]
  }

  expect_failures = [var.cluster_endpoint_private_access]
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

run "reject_public_access_split_across_ipv4_space" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/1", "128.0.0.0/1"]
  }

  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}

run "reject_irsa_disabled_with_ebs_csi" {
  command = plan

  variables {
    enable_irsa = false
  }

  expect_failures = [var.enable_irsa]
}

run "reject_ssh_key_without_sources" {
  command = plan

  variables {
    eks_ssh_key_name = "mock-admin-key"
  }

  expect_failures = [var.eks_ssh_source_security_group_ids]
}

run "reject_ssh_sources_without_key" {
  command = plan

  variables {
    eks_ssh_source_security_group_ids = ["sg-00000000000000011"]
  }

  expect_failures = [var.eks_ssh_source_security_group_ids]
}

run "reject_external_https_without_nat" {
  command = plan

  variables {
    eks_external_https_cidrs = ["203.0.113.0/24"]
  }

  expect_failures = [var.eks_external_https_cidrs]
}

run "reject_unrestricted_external_https" {
  command = plan

  variables {
    enable_nat_gateway       = true
    eks_external_https_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.eks_external_https_cidrs]
}

run "reject_external_https_split_across_ipv4_space" {
  command = plan

  variables {
    enable_nat_gateway       = true
    eks_external_https_cidrs = ["0.0.0.0/1", "128.0.0.0/1"]
  }

  expect_failures = [var.eks_external_https_cidrs]
}

run "reject_ipv6_external_https" {
  command = plan

  variables {
    enable_nat_gateway       = true
    eks_external_https_cidrs = ["2001:db8::/32"]
  }

  expect_failures = [var.eks_external_https_cidrs]
}

run "reject_malformed_external_https" {
  command = plan

  variables {
    enable_nat_gateway       = true
    eks_external_https_cidrs = ["203.0.113.0/33"]
  }

  expect_failures = [var.eks_external_https_cidrs]
}

run "reject_fractional_webhook_port" {
  command = plan

  variables {
    eks_control_plane_webhook_ports = [8443.5]
  }

  expect_failures = [var.eks_control_plane_webhook_ports]
}

run "reject_out_of_range_webhook_port" {
  command = plan

  variables {
    eks_control_plane_webhook_ports = [65536]
  }

  expect_failures = [var.eks_control_plane_webhook_ports]
}

run "reject_duplicate_builtin_webhook_port" {
  command = plan

  variables {
    eks_control_plane_webhook_ports = [443]
  }

  expect_failures = [var.eks_control_plane_webhook_ports]
}

run "reject_per_az_nat_with_unmatched_subnet_counts" {
  command = plan

  variables {
    enable_nat_gateway         = true
    single_nat_gateway         = false
    private_subnet_cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  }

  expect_failures = [var.single_nat_gateway]
}

run "explicit_network_options_remain_configurable" {
  command = plan

  variables {
    enable_nat_gateway                         = true
    eks_enable_ssm                             = true
    eks_api_admin_security_group_ids           = ["sg-00000000000000011"]
    eks_ssh_key_name                           = "mock-admin-key"
    eks_ssh_source_security_group_ids          = ["sg-00000000000000012"]
    eks_control_plane_webhook_ports            = [8443, 9443]
    eks_external_https_cidrs                   = ["203.0.113.0/24"]
    eks_additional_interface_endpoint_services = ["logs"]
    eks_s3_read_bucket_arns                    = ["arn:aws:s3:::mock-read-bucket"]
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 1
    error_message = "An explicit external HTTPS configuration must retain its opt-in NAT route."
  }
}
