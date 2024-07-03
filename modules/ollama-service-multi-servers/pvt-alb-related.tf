# Internal facing ALB for LLM servers, listener rule, target group

# ALB
resource "aws_lb" "llm" {
  name               = "${var.prefix}-alb"
  load_balancer_type = "application"
  internal           = true

  enable_deletion_protection = false
  subnets                    = var.subnet_ids

  security_groups = [aws_security_group.llm_alb_sg.id]
}

# target group & attachement
resource "aws_lb_target_group" "llm_http" {
  for_each = tomap(local.ec2_configs)

  name             = each.key
  port             = each.value.app_port
  protocol         = "HTTP"
  protocol_version = "HTTP1"
  target_type      = "instance"
  vpc_id           = var.vpc_id

  load_balancing_cross_zone_enabled = true

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  health_check {
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

resource "aws_lb_target_group_attachment" "llm_http" {
  for_each = tomap(local.ec2_configs)

  target_group_arn = aws_lb_target_group.llm_http[each.key].arn
  target_id        = aws_instance.llm[each.key].id
  port             = each.value.app_port
}


# Listener
resource "aws_lb_listener" "llm_http" {
  load_balancer_arn = aws_lb.llm.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.llm_http[
      [for k, v in local.ec2_configs : k if v.use_as_main_ec2][0]
    ].arn
  }
}

# Listener rule
resource "aws_lb_listener_rule" "llm_http" {
  for_each = local.ec2_configs

  listener_arn = aws_lb_listener.llm_http.arn
  priority     = each.value.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.llm_http[each.key].arn
  }

  condition {
    query_string {
      key   = "redirect_model"
      value = each.value.llm_model
    }
    query_string {
      key   = "redirect_name"
      value = each.value.llm_model
    }
  }
}


# SG for llm Internal ALB
resource "aws_security_group" "llm_alb_sg" {
  name        = "${var.prefix}-alb-sg"
  description = "Security group for llm internal ALB"
  vpc_id      = var.vpc_id
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
  cidr_ipv4         = var.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_alb_ingress_2" {
  security_group_id = aws_security_group.llm_alb_sg.id
  description       = "Traffic over HTTP (llm ec2) from VPC"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_alb_ingress_3" {
  count = var.open_webui_port != 0 ? 0 : 1

  security_group_id = aws_security_group.llm_alb_sg.id
  description       = "Traffic over port (for open webui) from VPC"
  from_port         = var.open_webui_port
  to_port           = var.open_webui_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}
