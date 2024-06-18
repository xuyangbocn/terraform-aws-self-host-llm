# Internal facing ALB for LLM servers, listener rule, target group
module "llm_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.9.0"

  name               = local.llm_alb_config.name
  load_balancer_type = local.llm_alb_config.type
  internal           = local.llm_alb_config.internal
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.private_subnets

  # Security Group
  create_security_group = false
  security_groups       = [aws_security_group.llm_alb_sg.id]

  # Listener
  listeners = {
    http = {
      port     = local.llm_alb_config.listener_llm["port"]
      protocol = local.llm_alb_config.listener_llm["protocol"]

      # default action
      forward = {
        target_group_key = "tg-llm"
      }
    }
  }

  # Target Groups
  target_groups = {
    tg-llm = {
      name_prefix = local.llm_alb_config.llm_target_group["name_prefix"]
      target_type = local.llm_alb_config.llm_target_group["target_type"]

      vpc_id           = module.vpc.vpc_id
      protocol         = local.llm_alb_config.llm_target_group["protocol"]
      protocol_version = local.llm_alb_config.llm_target_group["protocol_version"]
      port             = local.llm_alb_config.llm_target_group["port"]
      target_id        = aws_instance.llm_arm.id

      load_balancing_cross_zone_enabled = true
      stickiness = {
        type            = "lb_cookie"
        enabled         = true
        cookie_duration = 86400
      }

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        unhealthy_threshold = 2
        interval            = 30
        matcher             = 200
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
      }
    }
  }

  tags = local.tags
}

# SG for llm Internal ALB
resource "aws_security_group" "llm_alb_sg" {
  name        = "llm-alb-sg"
  description = "Security group for llm internal ALB"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "llm_alb_egress_1" {
  security_group_id = aws_security_group.llm_alb_sg.id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_vpc_security_group_ingress_rule" "llm_alb_ingress_1" {
  security_group_id = aws_security_group.llm_alb_sg.id
  description       = "Traffic over TLS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_alb_ingress_2" {
  security_group_id = aws_security_group.llm_alb_sg.id
  description       = "Traffic over HTTP (llm ec2) from VPC"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_alb_ingress_3" {
  security_group_id = aws_security_group.llm_alb_sg.id
  description       = "Traffic over port (for open webui) from VPC"
  from_port         = local.open_webui.port
  to_port           = local.open_webui.port
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}
