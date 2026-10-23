# The custom control-plane SG supplements, rather than replaces, the SG created
# by EKS. The launch template attaches ONLY eks_nodes to managed node interfaces.
# See NETWORK_SECURITY.md for this ownership boundary and migration requirements.
locals {
  interface_endpoint_services = setunion(
    toset(["ec2", "ecr.api", "ecr.dkr", "sts"]),
    var.enable_ssm ? toset(["ssm", "ssmmessages"]) : toset([]),
    var.additional_interface_endpoint_services
  )
  dns_protocols        = toset(["tcp", "udp"])
  webhook_ports        = toset([for port in var.control_plane_webhook_ports : tostring(port)])
  vpc_resolver_cidr    = "${cidrhost(var.vpc_cidr_block, 2)}/32"
  ecr_layer_bucket_arn = "arn:aws:s3:::prod-${var.aws_region}-starport-layer-bucket"
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-${var.environment}-cluster-sg"
  description = "Security group for the EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-cluster-sg"
    Environment = var.environment
  }, var.additional_tags)
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-${var.environment}-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge({
    Name                                          = "${var.project_name}-${var.environment}-node-sg"
    Environment                                   = var.environment
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }, var.additional_tags)
}

resource "aws_security_group" "endpoints" {
  name        = "${local.cluster_name}-endpoints-sg"
  description = "HTTPS from EKS nodes to private AWS service endpoints"
  vpc_id      = var.vpc_id

  # No initiated outbound connections are required. SGs allow response traffic
  # for established inbound connections automatically.
  tags = merge({
    Name        = "${local.cluster_name}-endpoints-sg"
    Environment = var.environment
  }, var.additional_tags)
}

# Retain existing resource addresses where rules have a narrower replacement.
resource "aws_security_group_rule" "cluster_egress" {
  type                     = "egress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Control plane to kubelet"
}

resource "aws_security_group_rule" "cluster_egress_https" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Control plane to HTTPS webhooks on nodes"
}

resource "aws_security_group_rule" "cluster_egress_dns" {
  for_each                 = local.dns_protocols
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = each.key
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Control plane to node-hosted DNS"
}

resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Allow nodes to communicate with the cluster API"
}

resource "aws_security_group_rule" "cluster_ingress_admin" {
  for_each                 = var.api_admin_security_group_ids
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = each.value
  description              = "Explicit private API administration source"
}

resource "aws_security_group_rule" "nodes_egress" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.endpoints.id
  description              = "Nodes to private AWS service endpoints"
}

resource "aws_security_group_rule" "nodes_egress_cluster" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description              = "Nodes to the private Kubernetes API"
}

resource "aws_security_group_rule" "nodes_egress_self" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_nodes.id
  self              = true
  description       = "Internal node and pod traffic within the node SG"
}

resource "aws_security_group_rule" "nodes_egress_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  prefix_list_ids   = [aws_vpc_endpoint.s3.prefix_list_id]
  description       = "Regional S3 HTTPS constrained by the gateway endpoint policy"
}

resource "aws_security_group_rule" "nodes_egress_dns" {
  for_each          = local.dns_protocols
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = each.key
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = [local.vpc_resolver_cidr]
  # Documents the expected resolver. SGs do not filter AmazonProvidedDNS;
  # enforcing DNS policy requires Route 53 Resolver DNS Firewall separately.
  description = "VPC DNS resolver path (not DNS Firewall enforcement)"
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.eks_nodes.id
  self              = true
  description       = "Allow nodes to communicate with each other"
}

resource "aws_security_group_rule" "nodes_ingress_cluster" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description              = "Control plane to kubelet"
}

resource "aws_security_group_rule" "nodes_ingress_cluster_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description              = "Control plane to HTTPS webhooks on nodes"
}

resource "aws_security_group_rule" "nodes_ingress_cluster_dns" {
  for_each                 = local.dns_protocols
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = each.key
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description              = "Control plane to node-hosted DNS"
}

resource "aws_security_group_rule" "endpoints_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Private AWS API requests from nodes"
}

resource "aws_security_group_rule" "cluster_egress_webhooks" {
  for_each                 = local.webhook_ports
  type                     = "egress"
  from_port                = tonumber(each.key)
  to_port                  = tonumber(each.key)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Explicit extra control-plane webhook port"
}

resource "aws_security_group_rule" "nodes_ingress_webhooks" {
  for_each                 = local.webhook_ports
  type                     = "ingress"
  from_port                = tonumber(each.key)
  to_port                  = tonumber(each.key)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description              = "Explicit extra control-plane webhook port"
}

resource "aws_security_group_rule" "nodes_egress_external" {
  count             = length(var.external_https_cidrs) > 0 ? 1 : 0
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = sort(tolist(var.external_https_cidrs))
  description       = "Explicit external HTTPS destinations; requires NAT routing"
}

resource "aws_security_group_rule" "nodes_ingress_ssh" {
  for_each                 = var.ssh_source_security_group_ids
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = each.value
  description              = "SSH from explicitly authorized source security groups"
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoint_services
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  # AWS's default endpoint policy is retained here. IAM still authorizes API
  # operations; these endpoints alone are not an account/repository data perimeter.
  tags = merge({
    Name        = "${local.cluster_name}-${replace(each.key, ".", "-")}-endpoint"
    Environment = var.environment
  }, var.additional_tags)
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  # ECR stores image layers in this regional S3 bucket. Additional object reads
  # require explicit bucket ARNs; writes/listing need a separately reviewed policy.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ReadECRLayersAndExplicitBuckets"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource = concat(
        ["${local.ecr_layer_bucket_arn}/*"],
        [for arn in sort(tolist(var.s3_read_bucket_arns)) : "${arn}/*"]
      )
    }]
  })

  tags = merge({
    Name        = "${local.cluster_name}-s3-endpoint"
    Environment = var.environment
  }, var.additional_tags)
}
