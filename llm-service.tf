module "llm_service" {
  source = "./modules/ollama-service-multi-servers"

  azs = var.azs

  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block
  subnet_ids     = module.vpc.private_subnets

  llm_ec2_configs = var.llm_ec2_configs

  open_webui_port = var.open_webui_port

  create_api_gw                   = var.create_api_gw
  api_gw_disable_execute_endpoint = var.api_gw_disable_execute_endpoint
  api_gw_domain                   = var.api_gw_domain
  api_gw_domain_route53_zone      = var.api_gw_domain_route53_zone
  api_gw_domain_ssl_cert_arn      = var.api_gw_domain_ssl_cert_arn
}
