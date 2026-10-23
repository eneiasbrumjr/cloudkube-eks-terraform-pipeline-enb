# EKS selects the AL2023 AMI and supplies its bootstrap configuration. Keeping
# the EKS-created cluster security group off these nodes makes this SG effective.
locals {
  node_instance_tags = merge(
    {
      Name        = "${local.cluster_name}-node"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
}

resource "aws_launch_template" "nodes" {
  name_prefix            = "${local.cluster_name}-nodes-"
  description            = "Managed EKS nodes with explicit network and metadata settings"
  vpc_security_group_ids = [aws_security_group.eks_nodes.id]
  key_name               = trimspace(var.eks_ssh_key_name) != "" ? trimspace(var.eks_ssh_key_name) : null

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.eks_disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.node_instance_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.node_instance_tags, { Name = "${local.cluster_name}-node-root" })
  }

  tags = merge(local.node_instance_tags, { Name = "${local.cluster_name}-nodes-lt" })

  lifecycle {
    create_before_destroy = true
  }
}
