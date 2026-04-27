# Outputs for networking and inventory generation

# output "nlb_dns_name" {
#   description = "DNS name of the Network Load Balancer"
#   value       = module.nlb.dns_name
# }

output "ssh_user" {
  description = "Default SSH user for Ubuntu instances"
  value       = "ubuntu"
}

output "nginx_public_ips" {
  description = "Public IPs of nginx instances (jump host candidates)"
  value = {
    for name, instance in aws_instance.infra :
    name => instance.public_ip
    if instance.tags.Role == "nginx"
  }
}

output "instance_private_ips_by_role" {
  description = "Private IPs of instances grouped by role"
  value = {
    backend = {
      for name, instance in aws_instance.infra :
      name => instance.private_ip
      if instance.tags.Role == "backend"
    }
    nginx = {
      for name, instance in aws_instance.infra :
      name => instance.private_ip
      if instance.tags.Role == "nginx"
    }
    monitoring = {
      for name, instance in aws_instance.infra :
      name => instance.private_ip
      if instance.tags.Role == "monitoring"
    }
  }
}

output "instance_ids_by_role" {
  description = "Instance IDs grouped by role"
  value = {
    backend = {
      for name, instance in aws_instance.infra :
      name => instance.id
      if instance.tags.Role == "backend"
    }
    nginx = {
      for name, instance in aws_instance.infra :
      name => instance.id
      if instance.tags.Role == "nginx"
    }
    monitoring = {
      for name, instance in aws_instance.infra :
      name => instance.id
      if instance.tags.Role == "monitoring"
    }
  }
}
