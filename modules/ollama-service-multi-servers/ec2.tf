# EC2, IAM role, security group

# LLM ec2 iam role and profile (Shared)
resource "aws_iam_role" "llm_ec2_iamr" {
  name               = "${var.prefix}-ec2-iamr"
  assume_role_policy = data.aws_iam_policy_document.llm_ec2_iamr_assume.json
}

resource "aws_iam_instance_profile" "llm_ec2_iam_profile" {
  name = "${var.prefix}-ec2-profile"
  role = aws_iam_role.llm_ec2_iamr.name
}

resource "aws_iam_role_policy_attachment" "llm_ec2_iam_policy" {
  for_each = toset(local.ec2_iamr_policies)

  role       = aws_iam_role.llm_ec2_iamr.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "llm_ec2_iamr_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# SG for LLM EC2 (Shared)
resource "aws_security_group" "llm_ec2_sg" {
  name        = "${var.prefix}-ec2-sg"
  description = "Security group for llm ec2"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "llm_ec2_egress_1" {
  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "llm_ec2_egress_2" {
  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Traffic to NFS port to EFS within VPC"
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_ec2_ingress_1" {
  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Traffic over TLS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_ec2_ingress_2" {
  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Traffic over HTTP from VPC"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_ec2_ingress_app_port" {
  for_each = toset([for k, v in local.ec2_configs : tostring(v.app_port)])

  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Traffic over Application (ollama) Port from VPC"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}

# EC2 instance for LLM (One for each Model)
resource "aws_instance" "llm" {
  for_each = local.ec2_configs

  ami                         = each.value.ami
  availability_zone           = each.value.az
  subnet_id                   = each.value.subnet_id
  instance_type               = each.value.instance_type
  iam_instance_profile        = aws_iam_instance_profile.llm_ec2_iam_profile.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.llm_ec2_sg.id]

  user_data                   = each.value.user_data
  user_data_replace_on_change = each.value.user_data_replace_on_change

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required" # IMDSv2
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = each.value.ebs_volume_gb
    volume_type           = "gp3"
  }
  tags = {
    System = "${var.prefix}"
    Name   = each.value.use_as_main_ec2 ? "${var.prefix}-main-${each.value.llm_model}" : "${var.prefix}-${each.value.llm_model}"
  }
}

resource "aws_ssm_document" "pull_models" {
  name          = "${var.prefix}-pull-models"
  document_type = "Command"

  content = file("${path.module}/aws-ssm-document/pull-models.json")
}

resource "aws_ssm_association" "pull_models" {
  for_each = local.ec2_configs

  name = aws_ssm_document.pull_models.name
  parameters = {
    "Models" = join(",", each.value.pull_models)
  }

  targets {
    key    = "InstanceIds"
    values = [aws_instance.llm[each.key].id]
  }
}
