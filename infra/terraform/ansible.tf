locals {
  ansible_user             = "ubuntu"
  ansible_ssh_common_args  = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand=\"ssh -i ${var.ssh_key_file} -W %h:%p -q ubuntu@${aws_instance.infra["monitoring"].public_ip} -o StrictHostKeyChecking=no\""
  ansible_private_key_file = var.ssh_key_file
}

resource "ansible_vault" "keepalived_vault" {
  vault_file          = "../ansible/roles/keepalived/vars/vault.yml"
  vault_password_file = "../ansible/.vault_pass"
}

resource "ansible_vault" "monitoring_vault" {
  vault_file          = "../ansible/roles/monitoring/vars/vault.yml"
  vault_password_file = "../ansible/.vault_pass"
}

data "ansible_inventory" "infra_inventory" {
  group {
    name = "all"
    vars = {
      ansible_user             = local.ansible_user
      ansible_ssh_common_args  = local.ansible_ssh_common_args
      ansible_private_key_file = local.ansible_private_key_file
      env_type                 = "aws"
    }

    group {
      name = "backend"
      vars = {
        workload_path = "../../../services"
      }
      host {
        name         = "backend"
        ansible_host = aws_instance.infra["backend"].private_ip
      }
    }

    group {
      name = "nginx"
      host {
        name         = "nginx1"
        ansible_host = aws_instance.infra["nginx1"].private_ip
      }
      host {
        name         = "nginx2"
        ansible_host = aws_instance.infra["nginx2"].private_ip
      }
    }

    group {
      name = "keepalived"
      vars = {
        vip_allocation_id = aws_eip.nginx_vip.id
      }

      group {
        name = "master"
        vars = {
          vrrp_role     = local.nodes.nginx1.vrrp_role
          vrrp_priority = tostring(local.nodes.nginx1.vrrp_priority)
        }
        host {
          name         = "nginx1"
          ansible_host = aws_instance.infra["nginx1"].private_ip
        }
      }

      group {
        name = "backup"
        vars = {
          vrrp_role     = local.nodes.nginx2.vrrp_role
          vrrp_priority = tostring(local.nodes.nginx2.vrrp_priority)
        }
        host {
          name         = "nginx2"
          ansible_host = aws_instance.infra["nginx2"].private_ip
        }
      }
    }

    group {
      name = "monitoring"
      host {
        name         = "monitoring"
        ansible_host = aws_instance.infra["monitoring"].public_ip
      }
    }
  }
}

# resource "local_file" "ansible_inventory_json" {
#   content  = data.ansible_inventory.infra_inventory.json
#   filename = "${path.module}/inventory.json"
# }

action "ansible_playbook_run" "ansible" {
  config {
    playbooks   = ["${path.module}/../ansible/site.yml"]
    inventories = [data.ansible_inventory.infra_inventory.json]
  }
}
