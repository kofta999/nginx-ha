locals {
  nodes = {
    "backend" = {
      type   = "t3.micro"
      role   = "backend"
      public = false
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
    # Note: It's better to use a dedicated bastion host but to save on costs I'll use monitoring node
    "monitoring" = {
      type   = "t3.micro"
      role   = "monitoring"
      public = true
    }
  }
}

module "ec2_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name = "ec2-role"

  trust_policy_permissions = {
    AllowEC2ToAssume = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    "ec2-eip-association-policy" = {
      sid    = "AllowAssociateDisassociateEip"
      effect = "Allow"
      actions = [
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress"
      ]
      resources = ["*"]
    }
  }

  create_instance_profile = true
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
  iam_instance_profile = module.ec2_iam_role.instance_profile_name

  subnet_id = each.value.public ? module.main_vpc.public_subnets[0] : module.main_vpc.private_subnets[0]

  vpc_security_group_ids = each.value.role == "nginx" ? [
    module.internal_sg.id,
    module.nginx_sg.id
    ] : each.value.role == "monitoring" ? [
    module.internal_sg.id,
    module.monitoring_sg.id
    ] : [
    module.internal_sg.id
  ]

  associate_public_ip_address = each.value.public && each.value.role == "monitoring" || each.value.role == "nginx"

  key_name = var.ssh_key_name

  tags = {
    Name         = each.key
    Role         = each.value.role
    VrrpRole     = try(each.value.vrrp_role, null)
    VrrpPriority = try(tostring(each.value.vrrp_priority), null)
  }

  # Enables V1 instance metadata endpoint (no auth required)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }
}
