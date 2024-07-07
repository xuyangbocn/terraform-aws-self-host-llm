data "aws_ami" "dlami_arm" {
  # Supported EC2 instances: G5g. 
  # Release notes: https://docs.aws.amazon.com/dlami/latest/devguide/appendix-ami-release-notes.html

  most_recent = true
  name_regex  = "^Deep Learning ARM64 AMI OSS Nvidia Driver GPU PyTorch.*"
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "is-public"
    values = ["true"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "dlami_x86" {
  # Supported EC2 instances: G4dn, G5, G6, Gr6, P4, P4de, P5. 
  # Release notes: https://docs.aws.amazon.com/dlami/latest/devguide/appendix-ami-release-notes.html

  most_recent = true
  name_regex  = "^Deep Learning OSS Nvidia Driver AMI GPU PyTorch .*Amazon Linux 2.*"
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "is-public"
    values = ["true"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
