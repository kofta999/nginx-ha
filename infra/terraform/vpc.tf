module "main_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "main_vpc"
  cidr = "10.0.0.0/16"

  azs = ["us-east-1a"]

  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  create_igw         = true
}

module "nginx_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "nginx-sg"
  description = "Security Group for Nginx reverse proxies"
  vpc_id      = module.main_vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "ssh-tcp"]
  # AWS adds this by default but Terraform removes it
  egress_rules = ["all-all"]
}

module "internal_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "internal-sg"
  description = "Security Group for internal communication"
  vpc_id      = module.main_vpc.vpc_id

  ingress_cidr_blocks = [module.main_vpc.vpc_cidr_block]
  ingress_rules       = ["ssh-tcp"]

  egress_rules = ["all-all"]

  egress_with_self = [
    { rule = "all-all" }
  ]
  ingress_with_self = [
    { rule = "all-all" }
  ]
}

resource "aws_eip" "nginx_vip" {
  domain = "vpc"
}
