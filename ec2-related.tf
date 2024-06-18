# EC2, IAM role, security group

# LLM ec2 iam role and profile
resource "aws_iam_role" "llm_ec2_iamr" {
  name               = "llm-ec2-iamr"
  assume_role_policy = data.aws_iam_policy_document.llm_ec2_iamr_assume.json
}

resource "aws_iam_instance_profile" "llm_ec2_iam_profile" {
  name = "llm-ec2-profile"
  role = aws_iam_role.llm_ec2_iamr.name
}

resource "aws_iam_role_policy_attachment" "llm_ec2_iam_policy" {
  for_each   = toset(local.ec2_config.llm_ec2_iamr_policies)
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

# EC2 instance for LLM
resource "aws_instance" "llm_arm" {
  ami                         = local.ec2_config.dlami_id_arm
  availability_zone           = local.azs[var.region][0]
  subnet_id                   = module.vpc.private_subnets[0]
  instance_type               = local.ec2_config.instance_type_arm
  iam_instance_profile        = aws_iam_instance_profile.llm_ec2_iam_profile.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.llm_ec2_sg.id]

  user_data = local.ec2_config.user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required" # IMDSv2
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = local.ec2_config.volume_size
    volume_type           = "gp3"
  }
  tags = merge(local.tags, {
    Name = local.ec2_config.name
    }
  )
}

# SG for LLM EC2
resource "aws_security_group" "llm_ec2_sg" {
  name        = "llm-ec2-sg"
  description = "Security group for llm ec2"
  vpc_id      = module.vpc.vpc_id
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
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_ec2_ingress_1" {
  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Traffic over TLS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_ec2_ingress_2" {
  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Traffic over HTTP from VPC"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "llm_ec2_ingress_3" {
  security_group_id = aws_security_group.llm_ec2_sg.id
  description       = "Traffic over Ollama Port from VPC"
  from_port         = 11434
  to_port           = 11434
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block

}
