# Outputs for networking and inventory generation
output "ssh_user" {
  description = "Default SSH user for Ubuntu instances"
  value       = "ubuntu"
}

output "monitoring_public_ip" {
  description = "Public IP of monitoring host used as SSH jump host"
  value = one([
    for _, instance in aws_instance.infra :
    instance.public_ip
    if instance.tags.Role == "monitoring"
  ])
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
    bastion = {
      for name, instance in aws_instance.infra :
      name => instance.private_ip
      if instance.tags.Role == "bastion"
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

output "vip_allocation_id" {
  value = aws_eip.nginx_vip.id
}

output "instances_meta" {
  description = "Per-instance metadata derived from EC2 tags (used by inventory generation)"
  value = {
    for name, instance in aws_instance.infra :
    name => {
      role          = try(instance.tags.Role, "")
      vrrp_role     = try(instance.tags.VrrpRole, "")
      vrrp_priority = try(instance.tags.VrrpPriority, "")
    }
  }
}
