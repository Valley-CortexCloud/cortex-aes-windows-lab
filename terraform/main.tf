############################################
# Caller identity (used for the device name / tags)
############################################
data "aws_caller_identity" "current" {}

############################################
# Resolve the RDP source CIDR
#   If allowed_rdp_cidr is empty, auto-detect this machine's egress IP.
############################################
data "http" "my_ip" {
  count = var.allowed_rdp_cidr == "" ? 1 : 0
  url   = "https://checkip.amazonaws.com/"
}

locals {
  detected_ip = var.allowed_rdp_cidr == "" ? "${trimspace(data.http.my_ip[0].response_body)}/32" : var.allowed_rdp_cidr

  is_win11 = var.os_edition == "windows11"

  ami_id = local.is_win11 ? var.windows11_ami_id : one(data.aws_ssm_parameter.win2022[*].value)
}

############################################
# Latest Windows Server 2022 Full Base AMI (shared tenancy, AWS-provided)
############################################
data "aws_ssm_parameter" "win2022" {
  count = local.is_win11 ? 0 : 1
  name  = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

############################################
# Networking - use the account's default VPC to keep the lab minimal
############################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################
# Key pair (private key written locally, used to decrypt the admin password)
############################################
resource "tls_private_key" "lab" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lab" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.lab.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.lab.private_key_pem
  filename        = var.private_key_output_path
  file_permission = "0600"
}

############################################
# Security group - RDP from your IP only, all egress (needed for installs)
############################################
resource "aws_security_group" "lab" {
  name_prefix = "${var.name_prefix}-sg-"
  description = "Koi AES lab - RDP from a single source, all egress"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "RDP from the configured source only"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [local.detected_ip]
  }

  egress {
    description = "All outbound (package installs, AI tool downloads, Koi reporting)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

############################################
# IAM for SSM (Fleet Manager / Session Manager) - no inbound port needed to manage
############################################
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name_prefix        = "${var.name_prefix}-ssm-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name_prefix = "${var.name_prefix}-ssm-"
  role        = aws_iam_role.ssm.name
}

# Pick the first default-VPC subnet to launch into
data "aws_subnet" "selected" {
  id = tolist(data.aws_subnets.default.ids)[0]
}

############################################
# Dedicated host - ONLY for Windows 11 (client OS licensing requires host tenancy)
############################################
resource "aws_ec2_host" "win11" {
  count             = local.is_win11 ? 1 : 0
  instance_family   = split(".", var.instance_type)[0]
  availability_zone = data.aws_subnet.selected.availability_zone
  auto_placement    = "on"
  tags              = { Name = "${var.name_prefix}-dedicated-host" }
}

############################################
# The lab instance
############################################
resource "aws_instance" "lab" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.lab.id]
  key_name                    = aws_key_pair.lab.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = true
  get_password_data           = true

  # Windows 11 (client OS) must run on a dedicated host.
  tenancy = local.is_win11 ? "host" : "default"
  host_id = one(aws_ec2_host.win11[*].id)

  user_data = var.auto_provision ? templatefile("${path.module}/templates/bootstrap-userdata.ps1", {}) : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_gb
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  tags = {
    Name = "${var.name_prefix}-${var.os_edition}"
  }
}
