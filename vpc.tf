# VPC, pvt, pub subnets, NAT, VPCE and its sg
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  # general
  name                    = var.vpc_name
  cidr                    = var.vpc_cidr
  azs                     = var.azs
  enable_dns_hostnames    = true
  create_egress_only_igw  = false
  create_igw              = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_vpn_gateway      = false
  map_public_ip_on_launch = false

  # private subnets
  private_subnets      = var.vpc_private_subnets_cidrs
  private_subnet_names = var.vpc_private_subnets_names

  # public subnets
  public_subnets      = var.vpc_public_subnets_cidrs
  public_subnet_names = var.vpc_public_subnets_names

  # default nacl
  manage_default_network_acl = true
  default_network_acl_name   = "${var.vpc_name}-default-nacl"
  default_network_acl_ingress = [
    {
      rule_no    = 100
      action     = "deny"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no         = 101
      action          = "deny"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      ipv6_cidr_block = "::/0"
    },
  ]
  default_network_acl_egress = [
    {
      rule_no    = 100
      action     = "deny"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no         = 101
      action          = "deny"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      ipv6_cidr_block = "::/0"
    },
  ]

  # private nacls
  private_dedicated_network_acl = true
  private_inbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number     = 101
      rule_action     = "allow"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      ipv6_cidr_block = "::/0"
    }
  ]
  private_outbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number     = 101
      rule_action     = "allow"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      ipv6_cidr_block = "::/0"
    }
  ]

  # public nacls
  public_dedicated_network_acl = true
  public_inbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number     = 101
      rule_action     = "allow"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      ipv6_cidr_block = "::/0"
    }
  ]
  public_outbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number     = 101
      rule_action     = "allow"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      ipv6_cidr_block = "::/0"
    }
  ]

  # default security group
  manage_default_security_group  = true
  default_security_group_name    = "${var.vpc_name}-default-sg"
  default_security_group_egress  = []
  default_security_group_ingress = []

  # default route table
  manage_default_route_table = true
  default_route_table_name   = "${var.vpc_name}-default-rt"

  # dhcp options
  enable_dhcp_options = true

  # flow log
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_destination_type                       = "cloud-watch-logs"
  flow_log_cloudwatch_log_group_retention_in_days = 365

  # Tags
  tags = local.tags
}



# SG for vpce
resource "aws_security_group" "llm_vpc_vpce" {
  name        = "llm_vpc_vpce"
  description = "Security group for llm vpc vpce"
  vpc_id      = module.vpc.vpc_id

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "llm_vpc_vpce_ingress_1" {
  security_group_id = aws_security_group.llm_vpc_vpce.id
  description       = "Traffic over TLS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

# VPC Endpoint (aws native)
module "llm_vpc_aws_vpce" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.8.1"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [aws_security_group.llm_vpc_vpce.id]
  subnet_ids         = module.vpc.private_subnets

  endpoints = {
    s3 = {
      service_name    = "com.amazonaws.ap-southeast-1.s3"
      service_type    = "Gateway"
      route_table_ids = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)
      tags            = { Name = "vpce-llm-s3" }
    },
    # ssm = {
    #   service_name        = "com.amazonaws.ap-southeast-1.ssm"
    #   private_dns_enabled = true
    #   tags                = { Name = "vpce-llm-ssm" }
    # },
    # ec2messages = {
    #   service_name        = "com.amazonaws.ap-southeast-1.ec2messages"
    #   private_dns_enabled = true
    #   tags                = { Name = "vpce-llm-ec2messages" }
    # },
    # ssmmessages = {
    #   service_name        = "com.amazonaws.ap-southeast-1.ssmmessages"
    #   private_dns_enabled = true
    #   tags                = { Name = "vpce-llm-ssmmessages" }
    # }
  }

  tags = local.tags
}

# Default SG for private subnet workloads
resource "aws_security_group" "default_pvt_subnet_sg" {
  name        = "default-pvt-ec2-sg"
  description = "Security group for pvt subnet ec2"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "default_pvt_subnet_egress_1" {
  security_group_id = aws_security_group.default_pvt_subnet_sg.id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "default_pvt_subnet_ingress_1" {
  security_group_id = aws_security_group.default_pvt_subnet_sg.id
  description       = "Traffic over TLS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "default_pvt_subnet_ingress_2" {
  security_group_id = aws_security_group.default_pvt_subnet_sg.id
  description       = "Traffic over HTTP from VPC"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}


# Default SG for public subnet workloads
resource "aws_security_group" "default_pub_subnet_sg" {
  name        = "default-pub-ec2-sg"
  description = "Security group for pub subnet ec2"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "default_pub_subnet_egress_1" {
  security_group_id = aws_security_group.default_pub_subnet_sg.id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "default_pub_subnet_ingress_1" {
  security_group_id = aws_security_group.default_pub_subnet_sg.id
  description       = "All tcp traffic over TLS"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}
