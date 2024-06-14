# ALB, listener rule, target group
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.9.0"

  name               = local.alb_config.name
  load_balancer_type = local.alb_config.type
  internal           = local.alb_config.internal
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.private_subnets

  # Security Group
  create_security_group = false
  security_groups       = [aws_security_group.default_pvt_subnet_sg.id]

  # Listener
  listeners = {
    http = {
      port     = local.alb_config.listener["port"]
      protocol = local.alb_config.listener["protocol"]

      # default action
      forward = {
        target_group_key = "tg-llm"
      }
    }
  }

  # Target Groups
  target_groups = {
    tg-llm = {
      name_prefix = local.alb_config.llm_target_group["name_prefix"]
      target_type = local.alb_config.llm_target_group["target_type"]

      vpc_id           = module.vpc.vpc_id
      protocol         = local.alb_config.llm_target_group["protocol"]
      protocol_version = local.alb_config.llm_target_group["protocol_version"]
      port             = local.alb_config.llm_target_group["port"]
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
