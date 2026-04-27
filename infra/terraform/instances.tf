locals {
  nodes = {
    "backend" = {
      type          = "t3.micro"
      role          = "backend"
      vrrp_role     = ""
      vrrp_priority = 0
      public        = false
    }
    "bastion" = {
      type          = "t3.micro"
      role          = "bastion"
      vrrp_role     = ""
      vrrp_priority = 0
      public        = true
    }
    "nginx1" = {
      type          = "t3.micro"
      role          = "nginx"
      vrrp_role     = "MASTER"
      vrrp_priority = 101
      public        = true
    }
    "nginx2" = {
      type          = "t3.micro"
      role          = "nginx"
      vrrp_role     = "BACKUP"
      vrrp_priority = 100
      public        = true
    }
    "monitoring" = {
      type          = "t3.micro"
      role          = "monitoring"
      vrrp_role     = ""
      vrrp_priority = 0
      public        = false
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_eip_policy" {
  name = "ec2-eip-association-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssociateDisassociateEip"
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "infra" {
  for_each = local.nodes

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = each.value.type
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  subnet_id = each.value.public ? module.main_vpc.public_subnets[0] : module.main_vpc.private_subnets[0]

vpc_security_group_ids = each.value.role == "nginx" ? [
  module.internal_sg.security_group_id,
  module.nginx_sg.security_group_id
] : each.value.role == "bastion" ? [
  module.internal_sg.security_group_id,
  module.bastion_sg.security_group_id
] : [
  module.internal_sg.security_group_id
]

  associate_public_ip_address = each.value.public && each.value.role == "bastion"

  key_name = var.ssh_key_name

  tags = {
    Name         = each.key
    Role         = each.value.role
    VrrpRole     = each.value.vrrp_role
    VrrpPriority = tostring(each.value.vrrp_priority)
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }
}
