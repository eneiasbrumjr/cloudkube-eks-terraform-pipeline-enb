mock_provider "aws" {
  override_during = plan
  source          = "./tests/mocks/aws"
}

# Also mock the root module's second provider; no live provider is available here.
mock_provider "tls" {
  override_during = plan
  source          = "./tests/mocks/tls"
}

run "subnets_never_auto_assign_public_ips" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    project_name               = "mock-cloudkube"
    environment                = "dev"
    vpc_cidr_block             = "10.42.0.0/16"
    public_subnet_cidr_blocks  = ["10.42.1.0/24", "10.42.2.0/24"]
    private_subnet_cidr_blocks = ["10.42.3.0/24", "10.42.4.0/24"]
    enable_nat_gateway         = true
    single_nat_gateway         = true
  }

  # Distinct computed IDs make wiring assertions decidable during a mock plan.
  # Route, subnet, NAT, and IP-assignment arguments still come from the module.
  override_resource {
    target          = aws_vpc.main
    override_during = plan
    values          = { id = "vpc-00000000000000001" }
  }

  override_resource {
    target          = aws_subnet.public[0]
    override_during = plan
    values          = { id = "subnet-00000000000000001" }
  }

  override_resource {
    target          = aws_subnet.public[1]
    override_during = plan
    values          = { id = "subnet-00000000000000002" }
  }

  override_resource {
    target          = aws_subnet.private[0]
    override_during = plan
    values          = { id = "subnet-00000000000000003" }
  }

  override_resource {
    target          = aws_subnet.private[1]
    override_during = plan
    values          = { id = "subnet-00000000000000004" }
  }

  override_resource {
    target          = aws_eip.nat[0]
    override_during = plan
    values          = { id = "eipalloc-00000000000000001" }
  }

  override_resource {
    target          = aws_nat_gateway.main[0]
    override_during = plan
    values          = { id = "nat-00000000000000001" }
  }

  override_resource {
    target          = aws_internet_gateway.main
    override_during = plan
    values          = { id = "igw-00000000000000001" }
  }

  override_resource {
    target          = aws_route_table.public
    override_during = plan
    values          = { id = "rtb-00000000000000001" }
  }

  override_resource {
    target          = aws_route_table.private[0]
    override_during = plan
    values          = { id = "rtb-00000000000000002" }
  }

  override_resource {
    target          = aws_route_table.private[1]
    override_during = plan
    values          = { id = "rtb-00000000000000003" }
  }

  assert {
    condition = (
      length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2 &&
      alltrue([for subnet in aws_subnet.public : !subnet.map_public_ip_on_launch]) &&
      alltrue([for subnet in aws_subnet.private : !subnet.map_public_ip_on_launch])
    )
    error_message = "Neither public nor private subnets may automatically assign public IPv4 addresses."
  }

  assert {
    condition = (
      length(aws_nat_gateway.main) == 1 && length(aws_eip.nat) == 1 &&
      aws_eip.nat[0].domain == "vpc" &&
      aws_nat_gateway.main[0].allocation_id == aws_eip.nat[0].id &&
      aws_nat_gateway.main[0].subnet_id == aws_subnet.public[0].id &&
      aws_internet_gateway.main.vpc_id == aws_vpc.main.id
    )
    error_message = "The single-NAT path must retain its explicit Elastic IP, public subnet, and VPC internet gateway."
  }

  assert {
    condition = (
      length(aws_route_table.public.route) == 1 &&
      alltrue([
        for route in aws_route_table.public.route :
        route.cidr_block == "0.0.0.0/0" && route.gateway_id == aws_internet_gateway.main.id
      ]) &&
      length(aws_route_table_association.public) == 2 &&
      alltrue([
        for index, association in aws_route_table_association.public :
        association.subnet_id == aws_subnet.public[index].id &&
        association.route_table_id == aws_route_table.public.id
      ])
    )
    error_message = "Public subnets must retain their internet-gateway route and route-table associations."
  }

  assert {
    condition = (
      length(aws_route_table.private) == 2 &&
      alltrue([
        for table in aws_route_table.private :
        length(table.route) == 1 && alltrue([
          for route in table.route :
          route.cidr_block == "0.0.0.0/0" && route.nat_gateway_id == aws_nat_gateway.main[0].id
        ])
      ]) &&
      length(aws_route_table_association.private) == 2 &&
      alltrue([
        for index, association in aws_route_table_association.private :
        association.subnet_id == aws_subnet.private[index].id &&
        association.route_table_id == aws_route_table.private[index].id
      ])
    )
    error_message = "Private subnets must retain default routes through the shared NAT gateway and their route-table associations."
  }
}
