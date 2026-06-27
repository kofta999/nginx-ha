module "main_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "main_vpc"
  cidr = "10.0.0.0/16"

  azs = ["eu-north-1a"]

  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  create_igw         = true
}

module "nginx_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = "nginx-sg"
  description = "Security Group for Nginx reverse proxies"
  vpc_id      = module.main_vpc.vpc_id

  ingress_rules = {
    https = {
      from_port   = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
    http = {
      from_port   = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }


  # AWS adds this by default but Terraform removes it
  egress_rules = {
    all = {
      # All
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

module "monitoring_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "monitoring-sg"
  description = "Security Group for monitoring access"
  vpc_id      = module.main_vpc.vpc_id

  ingress_rules = {
    ssh = {
      from_port   = 22
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }

    grafana = {
      from_port = 3000
      to_port   = 3000
      protocol  = "tcp"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

module "internal_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "internal-sg"
  description = "Security Group for internal communication"
  vpc_id      = module.main_vpc.vpc_id

  ingress_rules = {
    ssh = {
      from_port   = 22
      ip_protocol = "tcp"
      cidr_ipv4   = module.main_vpc.vpc_cidr_block
    }

    all-from-self = {
      ip_protocol                  = "-1"
      referenced_security_group_id = "self"
      description                  = "All protocols from self"
    }
  }

  egress_rules = {
    all-to-self = {
      ip_protocol                  = "-1"
      referenced_security_group_id = "self"
      description                  = "All protocols to self"
    }
  }

}

resource "aws_eip" "nginx_vip" {
  domain = "vpc"
}
