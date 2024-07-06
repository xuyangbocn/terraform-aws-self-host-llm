locals {
  ami_id = {
    "g5g" : data.aws_ami.dlami_arm.id,
    "g4dn" : data.aws_ami.dlami_x86.id,
    "g5" : data.aws_ami.dlami_x86.id,
  }

  ec2_iamr_policies = [
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]

  user_data = <<-EOF
    #!/bin/bash
    # Enable GPU monitoring
    sudo systemctl enable dlami-cloudwatch-agent@partial
    sudo systemctl start dlami-cloudwatch-agent@partial

    # Download Ollama
    curl -fsSL https://ollama.com/install.sh | sh

    # Expose Ollama endpoints to external and over desired port
    mkdir -p /etc/systemd/system/ollama.service.d/
    {
      echo '[Service]';
      echo 'Environment="OLLAMA_HOST=0.0.0.0:%s"'
      echo 'Environment="OLLAMA_MODELS=/usr/share/ollama/.ollama/models"'
      echo 'Environment="OLLAMA_KEEP_ALIVE=%s"'
      echo 'Environment="OLLAMA_FLASH_ATTENTION=1"'
    } | tee /etc/systemd/system/ollama.service.d/override.conf

    # Enable ollama
    systemctl daemon-reload
    systemctl enable ollama
    systemctl start ollama

    EOF

  ec2_configs = {
    for i, v in var.llm_ec2_configs :
    replace(v.llm_model, ":", "") => {
      id                          = replace(v.llm_model, ":", "")
      llm_model                   = v.llm_model
      instance_family             = split(".", v.instance_type)[0]
      instance_type               = v.instance_type
      ami                         = v.ami_id == "" ? local.ami_id[split(".", v.instance_type)[0]] : v.ami_id
      ebs_volume_gb               = v.ebs_volume_gb
      subnet_id                   = element(var.subnet_ids, i)
      az                          = element(var.azs, i)
      app_port                    = v.app_port
      user_data                   = format(local.user_data, v.app_port, "6h")
      user_data_replace_on_change = false

      use_as_main_ec2        = i == 0 ? true : false
      pull_models            = i == 0 ? [for each in var.llm_ec2_configs : each.llm_model] : [v.llm_model]
      listener_rule_priority = i + 1
    }
  }

  apigw_configs = {
    create_custom_domain = tobool(
      var.create_api_gw &&
      var.api_gw_domain != "" &&
      var.api_gw_domain_route53_zone != "" &&
      var.api_gw_domain_ssl_cert_arn != ""
    )
    disable_execute_endpoint = tobool(
      var.api_gw_domain != "" &&
      var.api_gw_domain_route53_zone != "" &&
      var.api_gw_domain_ssl_cert_arn != ""
    ) ? var.api_gw_disable_execute_endpoint : false
  }
}
