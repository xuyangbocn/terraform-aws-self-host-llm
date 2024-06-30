# Internet facing ALB, listener rule, target group

# ALB
resource "aws_lb" "ow" {
  name               = "${var.prefix}-alb"
  load_balancer_type = "application"
  internal           = false

  enable_deletion_protection = false
  subnets                    = var.alb_subnet_ids

  security_groups = [aws_security_group.open_webui_alb_sg.id]
}

# target group (attachement not required, is defined in ECS Fargate)
resource "aws_lb_target_group" "ow_http" {
  name             = var.prefix
  port             = var.open_webui_port
  protocol         = "HTTP"
  protocol_version = "HTTP1"
  target_type      = "ip"
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

# Listener (listener rule not required, default is enough)
resource "aws_lb_listener" "ow_http" {
  load_balancer_arn = aws_lb.ow.arn
  port              = local.alb_configs.listener_port
  protocol          = local.alb_configs.listener_protocol
  ssl_policy        = local.alb_configs.listener_ssl_policy
  certificate_arn   = local.alb_configs.listener_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ow_http.arn
  }
}


# SG for open webui public facing ALB
resource "aws_security_group" "open_webui_alb_sg" {
  name        = "open-webui-alb-sg"
  description = "Security group for external facing open webui ALB"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "open_webui_alb_egress_1" {
  security_group_id = aws_security_group.open_webui_alb_sg.id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_vpc_security_group_ingress_rule" "open_webui_alb_ingress_1" {
  security_group_id = aws_security_group.open_webui_alb_sg.id
  description       = "Traffic over TLS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "open_webui_alb_ingress_2" {
  security_group_id = aws_security_group.open_webui_alb_sg.id
  description       = "Traffic over HTTP (llm ec2) from VPC"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "open_webui_alb_ingress_3" {
  security_group_id = aws_security_group.open_webui_alb_sg.id
  description       = "Traffic over port (for open webui) from VPC"
  from_port         = var.open_webui_port
  to_port           = var.open_webui_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# Route53 domain to expose ALB
resource "aws_route53_record" "open_webui" {
  count = local.alb_configs.create_domain ? 1 : 0

  name    = var.open_webui_domain
  type    = "A"
  zone_id = var.open_webui_domain_route53_zone

  alias {
    name                   = aws_lb.ow.dns_name
    zone_id                = aws_lb.ow.zone_id
    evaluate_target_health = false
  }
}
