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

# module "nlb" {
#   source = "terraform-aws-modules/alb/aws"

#   name               = "nginx-ha-nlb"
#   load_balancer_type = "network"
#   vpc_id             = module.main_vpc.vpc_id
#   subnets            = module.main_vpc.public_subnets # Publicly reachable

#   listeners = {
#     # Forward HTTPS traffic directly to Nginx
#     https = {
#       port     = 443
#       protocol = "TCP"
#       forward = {
#         target_group_key = "nginx-https"
#       }
#     }
#     # Optional: Forward HTTP so Nginx can do the 301 redirect to HTTPS
#     http = {
#       port     = 80
#       protocol = "TCP"
#       forward = {
#         target_group_key = "nginx-http"
#       }
#     }
#   }

#   target_groups = {
#     nginx-https = {
#       backend_protocol  = "TCP"
#       backend_port      = 443
#       target_type       = "instance"
#       create_attachment = false

#       health_check = {
#         enabled             = true
#         protocol            = "HTTP"
#         port                = "80"
#         path                = "/"
#         matcher             = "301"
#         interval            = 10
#         timeout             = 6
#         healthy_threshold   = 3
#         unhealthy_threshold = 3
#       }
#     }

#     nginx-http = {
#       backend_protocol  = "TCP"
#       backend_port      = 80
#       target_type       = "instance"
#       create_attachment = false

#       health_check = {
#         enabled             = true
#         protocol            = "HTTP"
#         port                = "80"
#         path                = "/"
#         matcher             = "301"
#         interval            = 10
#         timeout             = 6
#         healthy_threshold   = 3
#         unhealthy_threshold = 3
#       }
#     }
#   }
# }


# resource "aws_lb_target_group_attachment" "nginx_https" {
#   for_each         = { for k, v in aws_instance.infra : k => v if v.tags.Role == "nginx" }
#   target_group_arn = module.nlb.target_groups["nginx-https"].arn
#   target_id        = each.value.id
#   port             = 443
# }

# resource "aws_lb_target_group_attachment" "nginx_http" {
#   for_each         = { for k, v in aws_instance.infra : k => v if v.tags.Role == "nginx" }
#   target_group_arn = module.nlb.target_groups["nginx-http"].arn
#   target_id        = each.value.id
#   port             = 80
# }
