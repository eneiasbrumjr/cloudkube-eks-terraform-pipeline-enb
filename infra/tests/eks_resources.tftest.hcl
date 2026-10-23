# Exercise the real child module to inspect its planned resource arguments.
mock_provider "aws" {
  override_during = plan
  source          = "./tests/mocks/aws"
}

mock_provider "tls" {
  override_during = plan
  source          = "./tests/mocks/tls"
}

# Only computed identities are supplied. SG membership, rules, endpoint options,
# disk settings and metadata arguments are read from the real module plans.
override_resource {
  target          = aws_security_group.eks_cluster
  override_during = plan
  values          = { id = "sg-00000000000000001" }
}

override_resource {
  target          = aws_security_group.eks_nodes
  override_during = plan
  values          = { id = "sg-00000000000000002" }
}

override_resource {
  target          = aws_security_group.endpoints
  override_during = plan
  values          = { id = "sg-00000000000000003" }
}

override_resource {
  target          = aws_launch_template.nodes
  override_during = plan
  values = {
    id             = "lt-00000000000000001"
    latest_version = 7
  }
}

override_resource {
  target          = aws_vpc_endpoint.s3
  override_during = plan
  values          = { prefix_list_id = "pl-00000001" }
}

variables {
  project_name                         = "mock-cloudkube"
  environment                          = "dev"
  aws_region                           = "us-east-1"
  vpc_id                               = "vpc-00000000000000000"
  vpc_cidr_block                       = "10.42.0.0/16"
  private_route_table_ids              = ["rtb-00000000000000001", "rtb-00000000000000002"]
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

  assert {
    condition = (
      aws_launch_template.nodes.vpc_security_group_ids == toset([aws_security_group.eks_nodes.id]) &&
      aws_eks_node_group.main.launch_template[0].id == aws_launch_template.nodes.id &&
      aws_eks_node_group.main.launch_template[0].version == "7" &&
      aws_eks_node_group.main.launch_template[0].version == tostring(aws_launch_template.nodes.latest_version)
    )
    error_message = "Managed nodes must use the numeric launch-template version and attach only the restricted node SG."
  }

  assert {
    condition = (
      aws_launch_template.nodes.metadata_options[0].http_endpoint == "enabled" &&
      aws_launch_template.nodes.metadata_options[0].http_tokens == "required" &&
      aws_launch_template.nodes.metadata_options[0].http_put_response_hop_limit == 1
    )
    error_message = "Node metadata must require IMDSv2 and retain the explicit hop limit of one."
  }

  assert {
    condition = (
      length(aws_launch_template.nodes.block_device_mappings) == 1 &&
      aws_launch_template.nodes.block_device_mappings[0].device_name == "/dev/xvda" &&
      aws_launch_template.nodes.block_device_mappings[0].ebs[0].volume_type == "gp3" &&
      aws_launch_template.nodes.block_device_mappings[0].ebs[0].volume_size == 20 &&
      tobool(aws_launch_template.nodes.block_device_mappings[0].ebs[0].encrypted) &&
      tobool(aws_launch_template.nodes.block_device_mappings[0].ebs[0].delete_on_termination)
    )
    error_message = "The node root disk must use the requested size, encrypted gp3 storage and deletion on termination."
  }

  assert {
    condition = (
      aws_launch_template.nodes.image_id == null &&
      aws_launch_template.nodes.user_data == null &&
      length(aws_launch_template.nodes.iam_instance_profile) == 0 &&
      length(aws_launch_template.nodes.network_interfaces) == 0 &&
      length(aws_eks_node_group.main.remote_access) == 0 &&
      startswith(aws_eks_node_group.main.node_group_name_prefix, "mock-cloudkube-dev-") &&
      length(aws_eks_node_group.main.node_group_name_prefix) <= 36
    )
    error_message = "EKS must retain AMI/bootstrap/profile ownership, and replacement node groups need a unique-name prefix without incompatible remote_access settings."
  }
}

run "explicit_public_access_and_version_override" {
  command = plan

  module {
    source = "./modules/eks"
  }

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = true
    cluster_endpoint_public_access_cidrs = ["198.51.100.0/24"]
    eks_cluster_version                  = "1.31"
  }

  assert {
    condition = (
      aws_eks_cluster.main.vpc_config[0].endpoint_public_access &&
      aws_eks_cluster.main.vpc_config[0].endpoint_private_access &&
      aws_eks_cluster.main.vpc_config[0].public_access_cidrs == toset(["198.51.100.0/24"])
    )
    error_message = "Explicit public access must retain the trusted range and the private node-to-API path."
  }

  assert {
    condition     = aws_eks_cluster.main.version == "1.31" && aws_eks_node_group.main.version == "1.31"
    error_message = "An explicit version override must reach both the cluster and managed nodes."
  }
}

run "private_service_paths_and_scoped_security_groups" {
  command = plan

  module {
    source = "./modules/eks"
  }

  assert {
    condition = (
      aws_eks_cluster.main.vpc_config[0].security_group_ids == toset([aws_security_group.eks_cluster.id]) &&
      aws_eks_node_group.main.subnet_ids == toset(var.private_subnet_ids) &&
      alltrue([
        for rule in [aws_security_group_rule.cluster_ingress_nodes, aws_security_group_rule.nodes_egress_cluster] :
        rule.protocol == "tcp" && rule.from_port == 443 && rule.to_port == 443
      ]) &&
      aws_security_group_rule.cluster_ingress_nodes.type == "ingress" &&
      aws_security_group_rule.cluster_ingress_nodes.security_group_id == aws_security_group.eks_cluster.id &&
      aws_security_group_rule.cluster_ingress_nodes.source_security_group_id == aws_security_group.eks_nodes.id &&
      aws_security_group_rule.nodes_egress_cluster.type == "egress" &&
      aws_security_group_rule.nodes_egress_cluster.security_group_id == aws_security_group.eks_nodes.id &&
      aws_security_group_rule.nodes_egress_cluster.source_security_group_id == aws_security_group.eks_cluster.id
    )
    error_message = "Nodes in private subnets must reach the API on TCP 443 through reciprocal node/control-plane SG rules."
  }

  assert {
    condition = (
      alltrue([
        for rule in [aws_security_group_rule.cluster_egress, aws_security_group_rule.cluster_egress_https] :
        rule.type == "egress" && rule.protocol == "tcp" &&
        rule.security_group_id == aws_security_group.eks_cluster.id &&
        rule.source_security_group_id == aws_security_group.eks_nodes.id
      ]) &&
      aws_security_group_rule.cluster_egress.from_port == 10250 && aws_security_group_rule.cluster_egress.to_port == 10250 &&
      aws_security_group_rule.cluster_egress_https.from_port == 443 && aws_security_group_rule.cluster_egress_https.to_port == 443 &&
      alltrue([
        for rule in [aws_security_group_rule.nodes_ingress_cluster, aws_security_group_rule.nodes_ingress_cluster_https] :
        rule.type == "ingress" && rule.protocol == "tcp" &&
        rule.security_group_id == aws_security_group.eks_nodes.id &&
        rule.source_security_group_id == aws_security_group.eks_cluster.id
      ]) &&
      aws_security_group_rule.nodes_ingress_cluster.from_port == 10250 && aws_security_group_rule.nodes_ingress_cluster.to_port == 10250 &&
      aws_security_group_rule.nodes_ingress_cluster_https.from_port == 443 && aws_security_group_rule.nodes_ingress_cluster_https.to_port == 443
    )
    error_message = "Control-plane initiation must pair scoped egress and node ingress for kubelet 10250 and HTTPS 443."
  }

  assert {
    condition = (
      toset(keys(aws_security_group_rule.cluster_egress_dns)) == toset(["tcp", "udp"]) &&
      toset(keys(aws_security_group_rule.nodes_ingress_cluster_dns)) == toset(["tcp", "udp"]) &&
      alltrue([
        for protocol in ["tcp", "udp"] :
        aws_security_group_rule.cluster_egress_dns[protocol].type == "egress" &&
        aws_security_group_rule.cluster_egress_dns[protocol].protocol == protocol &&
        aws_security_group_rule.cluster_egress_dns[protocol].from_port == 53 &&
        aws_security_group_rule.cluster_egress_dns[protocol].to_port == 53 &&
        aws_security_group_rule.cluster_egress_dns[protocol].security_group_id == aws_security_group.eks_cluster.id &&
        aws_security_group_rule.cluster_egress_dns[protocol].source_security_group_id == aws_security_group.eks_nodes.id &&
        aws_security_group_rule.nodes_ingress_cluster_dns[protocol].type == "ingress" &&
        aws_security_group_rule.nodes_ingress_cluster_dns[protocol].protocol == protocol &&
        aws_security_group_rule.nodes_ingress_cluster_dns[protocol].from_port == 53 &&
        aws_security_group_rule.nodes_ingress_cluster_dns[protocol].to_port == 53 &&
        aws_security_group_rule.nodes_ingress_cluster_dns[protocol].security_group_id == aws_security_group.eks_nodes.id &&
        aws_security_group_rule.nodes_ingress_cluster_dns[protocol].source_security_group_id == aws_security_group.eks_cluster.id
      ])
    )
    error_message = "Both DNS transports from the control plane must be paired with ingress only on the node SG."
  }

  assert {
    condition = alltrue([
      for rule in [aws_security_group_rule.nodes_ingress_self, aws_security_group_rule.nodes_egress_self] :
      rule.protocol == "-1" && rule.self && rule.security_group_id == aws_security_group.eks_nodes.id
    ])
    error_message = "Unrestricted node/pod protocol access must remain scoped to the node SG itself."
  }

  assert {
    condition = (
      aws_security_group_rule.nodes_egress.type == "egress" &&
      aws_security_group_rule.nodes_egress.security_group_id == aws_security_group.eks_nodes.id &&
      aws_security_group_rule.nodes_egress.source_security_group_id == aws_security_group.endpoints.id &&
      aws_security_group_rule.endpoints_ingress_nodes.type == "ingress" &&
      aws_security_group_rule.endpoints_ingress_nodes.security_group_id == aws_security_group.endpoints.id &&
      aws_security_group_rule.endpoints_ingress_nodes.source_security_group_id == aws_security_group.eks_nodes.id &&
      alltrue([
        for rule in [aws_security_group_rule.nodes_egress, aws_security_group_rule.endpoints_ingress_nodes] :
        rule.protocol == "tcp" && rule.from_port == 443 && rule.to_port == 443
      ])
    )
    error_message = "AWS interface endpoints must accept only the scoped node-to-endpoint HTTPS path."
  }

  assert {
    condition = (
      toset(keys(aws_security_group_rule.nodes_egress_dns)) == toset(["tcp", "udp"]) &&
      alltrue([
        for protocol in ["tcp", "udp"] :
        aws_security_group_rule.nodes_egress_dns[protocol].type == "egress" &&
        aws_security_group_rule.nodes_egress_dns[protocol].protocol == protocol &&
        aws_security_group_rule.nodes_egress_dns[protocol].from_port == 53 &&
        aws_security_group_rule.nodes_egress_dns[protocol].to_port == 53 &&
        aws_security_group_rule.nodes_egress_dns[protocol].security_group_id == aws_security_group.eks_nodes.id &&
        toset(aws_security_group_rule.nodes_egress_dns[protocol].cidr_blocks) == toset(["10.42.0.2/32"])
      ])
    )
    error_message = "The documented VPC resolver path must use the VPC-derived /32 on TCP and UDP 53."
  }

  assert {
    condition = (
      toset(keys(aws_vpc_endpoint.interface)) == toset(["ec2", "ecr.api", "ecr.dkr", "sts"]) &&
      alltrue([
        for service, endpoint in aws_vpc_endpoint.interface :
        endpoint.vpc_id == var.vpc_id && endpoint.vpc_endpoint_type == "Interface" &&
        endpoint.service_name == "com.amazonaws.us-east-1.${service}" &&
        endpoint.private_dns_enabled && endpoint.subnet_ids == toset(var.private_subnet_ids) &&
        endpoint.security_group_ids == toset([aws_security_group.endpoints.id])
      ])
    )
    error_message = "Only the four required interface services must be created by default, with private DNS and the endpoint SG in every private subnet."
  }

  assert {
    condition = (
      aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway" &&
      aws_vpc_endpoint.s3.vpc_id == var.vpc_id &&
      aws_vpc_endpoint.s3.service_name == "com.amazonaws.us-east-1.s3" &&
      aws_vpc_endpoint.s3.route_table_ids == toset(var.private_route_table_ids) &&
      aws_security_group_rule.nodes_egress_s3.type == "egress" &&
      aws_security_group_rule.nodes_egress_s3.security_group_id == aws_security_group.eks_nodes.id &&
      aws_security_group_rule.nodes_egress_s3.protocol == "tcp" &&
      aws_security_group_rule.nodes_egress_s3.from_port == 443 && aws_security_group_rule.nodes_egress_s3.to_port == 443 &&
      toset(aws_security_group_rule.nodes_egress_s3.prefix_list_ids) == toset([aws_vpc_endpoint.s3.prefix_list_id]) &&
      length(jsondecode(aws_vpc_endpoint.s3.policy).Statement) == 1 &&
      jsondecode(aws_vpc_endpoint.s3.policy).Statement[0].Effect == "Allow" &&
      toset(jsondecode(aws_vpc_endpoint.s3.policy).Statement[0].Action) == toset(["s3:GetObject"]) &&
      toset(jsondecode(aws_vpc_endpoint.s3.policy).Statement[0].Resource) == toset(["arn:aws:s3:::prod-us-east-1-starport-layer-bucket/*"])
    )
    error_message = "S3 HTTPS must use the gateway prefix list and private route tables, permitting only reads of the regional ECR layer bucket by default."
  }

  assert {
    condition = (
      length(aws_iam_role_policy_attachment.eks_ssm_managed_instance_core) == 0 &&
      length(aws_security_group_rule.cluster_ingress_admin) == 0 &&
      length(aws_security_group_rule.cluster_egress_webhooks) == 0 &&
      length(aws_security_group_rule.nodes_ingress_webhooks) == 0 &&
      length(aws_security_group_rule.nodes_ingress_ssh) == 0 &&
      length(aws_security_group_rule.nodes_egress_external) == 0 &&
      aws_launch_template.nodes.key_name == null
    )
    error_message = "SSM permissions, administration, SSH, extra webhooks and external HTTPS must require explicit opt-in."
  }
}

run "explicit_network_options_are_scoped" {
  command = plan

  module {
    source = "./modules/eks"
  }

  variables {
    aws_region                             = "eu-west-1"
    eks_disk_size                          = 80
    eks_ssh_key_name                       = "mock-admin-key"
    enable_ssm                             = true
    api_admin_security_group_ids           = ["sg-00000000000000011"]
    ssh_source_security_group_ids          = ["sg-00000000000000012"]
    control_plane_webhook_ports            = [8443, 9443]
    external_https_cidrs                   = ["203.0.113.0/24", "198.51.100.0/24"]
    additional_interface_endpoint_services = ["logs", "ecr.api"]
    s3_read_bucket_arns                    = ["arn:aws:s3:::mock-read-bucket"]
  }

  assert {
    condition = (
      toset(keys(aws_vpc_endpoint.interface)) == toset(["ec2", "ecr.api", "ecr.dkr", "sts", "ssm", "ssmmessages", "logs"]) &&
      alltrue([
        for service, endpoint in aws_vpc_endpoint.interface :
        endpoint.service_name == "com.amazonaws.eu-west-1.${service}" &&
        endpoint.private_dns_enabled && endpoint.subnet_ids == toset(var.private_subnet_ids) &&
        endpoint.security_group_ids == toset([aws_security_group.endpoints.id])
      ]) &&
      length(aws_iam_role_policy_attachment.eks_ssm_managed_instance_core) == 1 &&
      aws_iam_role_policy_attachment.eks_ssm_managed_instance_core[0].policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" &&
      aws_iam_role_policy_attachment.eks_ssm_managed_instance_core[0].role == aws_iam_role.eks_nodes.name
    )
    error_message = "SSM must opt in to both its node policy and private services, while additional service names are deduplicated in the selected region."
  }

  assert {
    condition = (
      toset(keys(aws_security_group_rule.cluster_ingress_admin)) == toset(["sg-00000000000000011"]) &&
      aws_security_group_rule.cluster_ingress_admin["sg-00000000000000011"].type == "ingress" &&
      aws_security_group_rule.cluster_ingress_admin["sg-00000000000000011"].security_group_id == aws_security_group.eks_cluster.id &&
      aws_security_group_rule.cluster_ingress_admin["sg-00000000000000011"].source_security_group_id == "sg-00000000000000011" &&
      aws_security_group_rule.cluster_ingress_admin["sg-00000000000000011"].protocol == "tcp" &&
      aws_security_group_rule.cluster_ingress_admin["sg-00000000000000011"].from_port == 443 &&
      aws_security_group_rule.cluster_ingress_admin["sg-00000000000000011"].to_port == 443 &&
      toset(keys(aws_security_group_rule.nodes_ingress_ssh)) == toset(["sg-00000000000000012"]) &&
      aws_security_group_rule.nodes_ingress_ssh["sg-00000000000000012"].type == "ingress" &&
      aws_security_group_rule.nodes_ingress_ssh["sg-00000000000000012"].security_group_id == aws_security_group.eks_nodes.id &&
      aws_security_group_rule.nodes_ingress_ssh["sg-00000000000000012"].source_security_group_id == "sg-00000000000000012" &&
      aws_security_group_rule.nodes_ingress_ssh["sg-00000000000000012"].protocol == "tcp" &&
      aws_security_group_rule.nodes_ingress_ssh["sg-00000000000000012"].from_port == 22 &&
      aws_security_group_rule.nodes_ingress_ssh["sg-00000000000000012"].to_port == 22 &&
      aws_launch_template.nodes.key_name == "mock-admin-key"
    )
    error_message = "API administration and SSH must use only their supplied source SGs and destination ports, with the SSH key on the launch template."
  }

  assert {
    condition = (
      toset(keys(aws_security_group_rule.cluster_egress_webhooks)) == toset(["8443", "9443"]) &&
      toset(keys(aws_security_group_rule.nodes_ingress_webhooks)) == toset(["8443", "9443"]) &&
      alltrue([
        for port in ["8443", "9443"] :
        aws_security_group_rule.cluster_egress_webhooks[port].type == "egress" &&
        aws_security_group_rule.cluster_egress_webhooks[port].protocol == "tcp" &&
        aws_security_group_rule.cluster_egress_webhooks[port].from_port == tonumber(port) &&
        aws_security_group_rule.cluster_egress_webhooks[port].to_port == tonumber(port) &&
        aws_security_group_rule.cluster_egress_webhooks[port].security_group_id == aws_security_group.eks_cluster.id &&
        aws_security_group_rule.cluster_egress_webhooks[port].source_security_group_id == aws_security_group.eks_nodes.id &&
        aws_security_group_rule.nodes_ingress_webhooks[port].type == "ingress" &&
        aws_security_group_rule.nodes_ingress_webhooks[port].protocol == "tcp" &&
        aws_security_group_rule.nodes_ingress_webhooks[port].from_port == tonumber(port) &&
        aws_security_group_rule.nodes_ingress_webhooks[port].to_port == tonumber(port) &&
        aws_security_group_rule.nodes_ingress_webhooks[port].security_group_id == aws_security_group.eks_nodes.id &&
        aws_security_group_rule.nodes_ingress_webhooks[port].source_security_group_id == aws_security_group.eks_cluster.id
      ])
    )
    error_message = "Extra webhook ports must be explicit reciprocal rules between the control-plane and node SGs."
  }

  assert {
    condition = (
      length(aws_security_group_rule.nodes_egress_external) == 1 &&
      aws_security_group_rule.nodes_egress_external[0].type == "egress" &&
      aws_security_group_rule.nodes_egress_external[0].security_group_id == aws_security_group.eks_nodes.id &&
      aws_security_group_rule.nodes_egress_external[0].protocol == "tcp" &&
      aws_security_group_rule.nodes_egress_external[0].from_port == 443 &&
      aws_security_group_rule.nodes_egress_external[0].to_port == 443 &&
      toset(aws_security_group_rule.nodes_egress_external[0].cidr_blocks) == toset(["203.0.113.0/24", "198.51.100.0/24"])
    )
    error_message = "Opt-in external traffic must retain exactly the supplied IPv4 destinations on HTTPS."
  }

  assert {
    condition = (
      length(jsondecode(aws_vpc_endpoint.s3.policy).Statement) == 1 &&
      toset(jsondecode(aws_vpc_endpoint.s3.policy).Statement[0].Action) == toset(["s3:GetObject"]) &&
      toset(jsondecode(aws_vpc_endpoint.s3.policy).Statement[0].Resource) == toset([
        "arn:aws:s3:::prod-eu-west-1-starport-layer-bucket/*",
        "arn:aws:s3:::mock-read-bucket/*"
      ]) &&
      aws_launch_template.nodes.block_device_mappings[0].ebs[0].volume_size == 80 &&
      tobool(aws_launch_template.nodes.block_device_mappings[0].ebs[0].encrypted)
    )
    error_message = "Explicit object-read buckets must augment only the regional ECR bucket, and a custom disk size must reach encrypted node storage."
  }
}
