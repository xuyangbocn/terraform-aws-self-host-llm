# EFS, mount target and etc
resource "aws_efs_file_system" "open_webui" {
  encrypted        = false
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  protection {
    replication_overwrite = "ENABLED"
  }

  tags = {
    Name = "open-webui"
  }
}

# Mount target: for workloads in pvt subnets
resource "aws_efs_mount_target" "efs_to_pvt_subnets" {
  for_each        = toset(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.open_webui.id
  security_groups = [aws_security_group.efs_sg.id]
  subnet_id       = each.value
}

# SG for EFS
resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Security group for EFS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "efs_egress_1" {
  security_group_id = aws_security_group.efs_sg.id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "efs_ingress_1" {
  security_group_id = aws_security_group.efs_sg.id
  description       = "Access EFS via NFS port"
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block
}
