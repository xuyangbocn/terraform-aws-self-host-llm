locals {
  # tags
  tags = {
    "system" = "llm"
  }

  ollama_port = 11434

  open_webui = {
    name      = "open-webui"
    image_url = var.open_webui_image_url
    arch      = "ARM64"
    os        = "LINUX"
    port      = 8080
    data_dir  = "/app/backend/data"
  }

  azs = {
    "ap-southeast-1" : { 0 : "ap-southeast-1a", 1 : "ap-southeast-1b", 2 : "ap-southeast-1c" }
  }

  vpc_config = {
    # general
    name = "llm-vpc"
    cidr = "172.31.0.0/16"
    azs  = slice(values(local.azs[var.region]), 0, 3)

    # private subnets
    private_subnet_names = ["private-48-1a", "private-64-1b", "private-80-1c"]
    private_subnets      = ["172.31.48.0/20", "172.31.64.0/20", "172.31.80.0/20"]

    # public subnets
    public_subnet_names = ["public-0-1a", "public-16-1b", "public-32-1c"]
    public_subnets      = ["172.31.0.0/20", "172.31.16.0/20", "172.31.32.0/20"]

    # default nacl
    default_network_acl_name = "llm-vpc-default-nacl"

    # default security group
    default_security_group_name = "llm-vpc-default-sg"

    # default route table
    default_route_table_name   = "llm-vpc-default-rt"
    default_route_table_routes = [{}] #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_route_table#route

    # flow log
    flow_log_destination_type                       = "cloud-watch-logs"
    flow_log_cloudwatch_log_group_retention_in_days = 365
  }

  ec2_config = {
    name              = "llm-ec2"
    instance_type_arm = "g5g.xlarge"            # ARM chip
    dlami_id_arm      = "ami-0efbb02a15eb547ab" # ARM DLAMI,
    instance_type_x86 = "g4dn.xlarge"           # X86 Chip
    dlami_id_x86      = "ami-07d5375b624cbd745" # X86 DLAMI: Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.3.0 (Amazon Linux 2) 20240611	
    volume_size       = 200
    llm_ec2_iamr_policies = [
      "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
      "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy",
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    ]
    user_data = <<EOF
#!/bin/bash
# Enable GPU monitoring
sudo systemctl enable dlami-cloudwatch-agent@partial
sudo systemctl start dlami-cloudwatch-agent@partial

# Download Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Expose Ollama endpoints
mkdir -p /c
{
  echo '[Service]';
  echo 'Environment="OLLAMA_HOST=0.0.0.0:${local.ollama_port}"'
} | tee /etc/systemd/system/ollama.service.d/override.conf

systemctl daemon-reload
systemctl enable ollama
systemctl start ollama
EOF

  }

  llm_alb_config = {
    name     = "llm-alb"
    type     = "application"
    internal = true

    listener_llm = {
      port     = 80
      protocol = "HTTP"
    }

    llm_target_group = {
      name_prefix      = "llm-"
      port             = local.ollama_port
      protocol         = "HTTP"
      protocol_version = "HTTP1"
      target_type      = "instance"
    }
  }

  open_webui_alb_config = {
    name     = "open-webui-alb"
    type     = "application"
    internal = false

    listener_open_webui = {
      port            = var.open_webui_domain_ssl_cert_arn == "" ? 80 : 443
      protocol        = var.open_webui_domain_ssl_cert_arn == "" ? "HTTP" : "HTTPS"
      ssl_policy      = var.open_webui_domain_ssl_cert_arn == "" ? null : "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
      certificate_arn = var.open_webui_domain_ssl_cert_arn == "" ? null : var.open_webui_domain_ssl_cert_arn
    }

    open_webui_target_group = {
      name_prefix      = "ow-"
      port             = local.open_webui.port
      protocol         = "HTTP"
      protocol_version = "HTTP1"
      target_type      = "ip"
    }

    domain = {
      create          = tobool(var.open_webui_domain != "" && var.open_webui_domain_route53_zone != "" && var.open_webui_domain_ssl_cert_arn != "")
      domain_name     = var.open_webui_domain
      certificate_arn = var.open_webui_domain_ssl_cert_arn
      route53_zone_id = var.open_webui_domain_route53_zone
    }
  }

  apigw_config = {
    name                         = "llm-apigw"
    protocol_type                = "HTTP"
    disable_execute_api_endpoint = var.disable_execute_api_endpoint
    route_post                   = "POST /{ollamaApiPath+}"
    route_get                    = "GET /{ollamaApiPath+}"
    stage = {
      name        = "$default"
      auto_deploy = true
    }

    custom_domain = {
      create          = tobool(var.api_gw_domain != "" && var.api_gw_domain_route53_zone != "" && var.api_gw_domain_ssl_cert_arn != "")
      domain_name     = var.api_gw_domain
      certificate_arn = var.api_gw_domain_ssl_cert_arn
      route53_zone_id = var.api_gw_domain_route53_zone
    }
  }

  ecs_config = {
    open_webui_service = {
      desired_count = 3
      cpu           = 1024
      memory        = 2048
    }
    open_webui_ecs_iamr_policies = [
      "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
      "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess",
      "arn:aws:iam::aws:policy/AmazonElasticFileSystemReadOnlyAccess",
    ]
  }

}
