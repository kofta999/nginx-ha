locals {
  nodes = {
    "backend"    = { type = "t3.micro", role = "backend" }
    "nginx1"     = { type = "t3.micro", role = "nginx" }
    "nginx2"     = { type = "t3.micro", role = "nginx" }
    "monitoring" = { type = "t3.micro", role = "monitoring" }
  }
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

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.type


  subnet_id                   = each.value.role == "nginx" ? module.main_vpc.public_subnets[0] : module.main_vpc.private_subnets[0]
  vpc_security_group_ids      = each.value.role == "nginx" ? [module.internal_sg.security_group_id, module.nginx_sg.security_group_id] : [module.internal_sg.security_group_id]
  associate_public_ip_address = each.value.role == "nginx" ? true : false
  
  key_name = var.ssh_key_name

  tags = {
    Name = each.key
    Role = each.value.role
  }
}
