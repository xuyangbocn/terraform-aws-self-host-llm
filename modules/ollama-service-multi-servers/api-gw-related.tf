# API gateway, custom domain, vpc link, lambda auth

# VPC Link
resource "aws_apigatewayv2_vpc_link" "llm" {
  count = var.create_api_gw ? 1 : 0

  name               = "${var.prefix}-apigw"
  security_group_ids = [aws_security_group.llm_vpc_link_sg[0].id]
  subnet_ids         = var.subnet_ids

}

# SG for VPC Link (from API GW to ALB behind)
# ref: https://repost.aws/questions/QUXW5Sb3dyS-i0wpMuyXJrPw/http-apigw-with-vpclink
resource "aws_security_group" "llm_vpc_link_sg" {
  count = var.create_api_gw ? 1 : 0

  name        = "${var.prefix}-vpc-link-sg"
  description = "Security group for vpc link for llm api gateway"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "llm_vpc_link_egress_1" {
  count = var.create_api_gw ? 1 : 0

  security_group_id = aws_security_group.llm_vpc_link_sg[0].id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}

# API Gateway
resource "aws_apigatewayv2_api" "llm_apigw" {
  count = var.create_api_gw ? 1 : 0

  name                         = "${var.prefix}-apigw"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = local.apigw_configs.disable_execute_endpoint
}

resource "aws_apigatewayv2_route" "root_post" {
  count = var.create_api_gw ? 1 : 0

  api_id    = aws_apigatewayv2_api.llm_apigw[0].id
  route_key = "POST /{ollamaApiPath+}"
  target    = "integrations/${aws_apigatewayv2_integration.root_post[0].id}"
}

resource "aws_apigatewayv2_integration" "root_post" {
  count = var.create_api_gw ? 1 : 0

  api_id             = aws_apigatewayv2_api.llm_apigw[0].id
  integration_type   = "HTTP_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lb_listener.llm_http.arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.llm[0].id

  request_parameters = {
    "append:querystring.redirect_model" = "$request.body.model"
    "append:querystring.redirect_name"  = "$request.body.name"
  }

}

resource "aws_apigatewayv2_route" "root_get" {
  count = var.create_api_gw ? 1 : 0

  api_id    = aws_apigatewayv2_api.llm_apigw[0].id
  route_key = "GET /{ollamaApiPath+}"
  target    = "integrations/${aws_apigatewayv2_integration.root_get[0].id}"
}

resource "aws_apigatewayv2_integration" "root_get" {
  count = var.create_api_gw ? 1 : 0

  api_id             = aws_apigatewayv2_api.llm_apigw[0].id
  integration_type   = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri    = aws_lb_listener.llm_http.arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.llm[0].id
}

resource "aws_apigatewayv2_route" "root_delete" {
  count = var.create_api_gw ? 1 : 0

  api_id    = aws_apigatewayv2_api.llm_apigw[0].id
  route_key = "DELETE /{ollamaApiPath+}"
  target    = "integrations/${aws_apigatewayv2_integration.root_delete[0].id}"
}

resource "aws_apigatewayv2_integration" "root_delete" {
  count = var.create_api_gw ? 1 : 0

  api_id             = aws_apigatewayv2_api.llm_apigw[0].id
  integration_type   = "HTTP_PROXY"
  integration_method = "DELETE"
  integration_uri    = aws_lb_listener.llm_http.arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.llm[0].id
}

resource "aws_apigatewayv2_stage" "llm_auto_deploy" {
  count = var.create_api_gw ? 1 : 0

  api_id      = aws_apigatewayv2_api.llm_apigw[0].id
  name        = "$default"
  auto_deploy = true

}

# Custom domain
resource "aws_apigatewayv2_domain_name" "llm" {
  count = local.apigw_configs.create_custom_domain ? 1 : 0

  domain_name = var.api_gw_domain

  domain_name_configuration {
    certificate_arn = var.api_gw_domain_ssl_cert_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "llm" {
  count = local.apigw_configs.create_custom_domain ? 1 : 0

  name    = aws_apigatewayv2_domain_name.llm[0].domain_name
  type    = "A"
  zone_id = var.api_gw_domain_route53_zone

  alias {
    name                   = aws_apigatewayv2_domain_name.llm[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.llm[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_apigatewayv2_api_mapping" "llm" {
  count = local.apigw_configs.create_custom_domain ? 1 : 0

  api_id      = aws_apigatewayv2_api.llm_apigw[0].id
  domain_name = aws_apigatewayv2_domain_name.llm[0].id
  stage       = aws_apigatewayv2_stage.llm_auto_deploy[0].id
}
