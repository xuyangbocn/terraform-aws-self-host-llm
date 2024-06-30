locals {
  open_webui = {
    arch     = "ARM64"
    os       = "LINUX"
    data_dir = "/app/backend/data"
  }

  ecs_iamr_policies = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess",
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemReadOnlyAccess",
  ]

  alb_configs = {
    listener_port            = var.open_webui_domain_ssl_cert_arn == "" ? 80 : 443
    listener_protocol        = var.open_webui_domain_ssl_cert_arn == "" ? "HTTP" : "HTTPS"
    listener_ssl_policy      = var.open_webui_domain_ssl_cert_arn == "" ? null : "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
    listener_certificate_arn = var.open_webui_domain_ssl_cert_arn == "" ? null : var.open_webui_domain_ssl_cert_arn

    create_domain = tobool(
      var.open_webui_domain != "" &&
      var.open_webui_domain_route53_zone != "" &&
      var.open_webui_domain_ssl_cert_arn != ""
    )
  }
}
