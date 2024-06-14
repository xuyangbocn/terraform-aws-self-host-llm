locals {
  # tags
  tags = {
    "system" = "llm"
  }

  ollama_port = 11434

  apse1_azs = { 0 : "ap-southeast-1a", 1 : "ap-southeast-1b", 2 : "ap-southeast-1c" }

  vpc_config = {
    # general
    name = "llm-vpc"
    cidr = "172.31.0.0/16"
    azs  = slice(values(local.apse1_azs), 0, 3)

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
    dlami_id_x86      = "ami-067e51faa76313ade" # X86 DLAMI
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
mkdir -p /etc/systemd/system/ollama.service.d
{
  echo '[Service]';
  echo 'Environment="OLLAMA_HOST=0.0.0.0:${local.ollama_port}"'
} | tee /etc/systemd/system/ollama.service.d/override.conf

systemctl daemon-reload
systemctl restart ollama
EOF

  }

  alb_config = {
    name     = "llm-alb"
    type     = "application"
    internal = true

    listener = {
      port     = 80
      protocol = "HTTP"
    }

    llm_target_group = {
      name_prefix      = "tg-llm"
      port             = local.ollama_port
      protocol         = "HTTP"
      protocol_version = "HTTP1"
      target_type      = "instance"
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

    custom_domain_name = {
      create          = tobool(var.custom_domain_name != "" && var.custom_domain_name_route53_zone != "" && var.custom_domain_name_ssl_cert_arn != "")
      domain_name     = var.custom_domain_name
      certificate_arn = var.custom_domain_name_ssl_cert_arn
      route53_zone_id = var.custom_domain_name_route53_zone
    }
  }
}
