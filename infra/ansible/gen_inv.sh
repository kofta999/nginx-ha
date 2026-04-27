#!/usr/bin/env sh
set -eu

TF_DIR="../terraform"
OUT_FILE="./inventory_aws_ssh.ini"

# Optional override:
#   SSH_KEY_FILE=/home/you/.ssh/your-key.pem ./gen_inv.sh
SSH_KEY_FILE="${SSH_KEY_FILE:-/home/kofta/Downloads/kofta.pem}"

# Requires jq
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install jq first."
  exit 1
fi

# Requires terraform outputs to exist
tf_json="$(terraform -chdir="${TF_DIR}" output -json)"
private_ips="$(printf '%s' "${tf_json}" | jq -r '.instance_private_ips_by_role.value')"
public_ips="$(printf '%s' "${tf_json}" | jq -r '.nginx_public_ips.value')"
bastion_public_ip="$(printf '%s' "${tf_json}" | jq -r '.bastion_public_ip.value // empty')"
eip_alloc_id="$(printf '%s' "${tf_json}" | jq -r '.vip_allocation_id.value // empty')"
instance_meta="$(printf '%s' "${tf_json}" | jq -r '.instances_meta.value // empty')"

backend_ip="$(printf '%s' "${private_ips}" | jq -r '.backend.backend // empty')"
monitoring_ip="$(printf '%s' "${private_ips}" | jq -r '.monitoring.monitoring // empty')"
nginx1_private="$(printf '%s' "${private_ips}" | jq -r '.nginx.nginx1 // empty')"
nginx2_private="$(printf '%s' "${private_ips}" | jq -r '.nginx.nginx2 // empty')"

# Jump host: use bastion public IP (stable admin entrypoint)
if [ -n "${bastion_public_ip}" ] && [ "${bastion_public_ip}" != "null" ]; then
  jump_ip="${bastion_public_ip}"
else
  echo "No bastion public IP found. Cannot build jump-host inventory."
  exit 1
fi

# Derive keepalived role/priority from Terraform output if available.
# Expected output shape:
# output "instances_meta" {
#   value = {
#     nginx1 = { vrrp_role = "MASTER", vrrp_priority = "101" }
#     nginx2 = { vrrp_role = "BACKUP", vrrp_priority = "100" }
#   }
# }
vrrp_role_nginx1="$(printf '%s' "${instance_meta}" | jq -r '.nginx1.vrrp_role // "MASTER"' 2>/dev/null || printf '%s' "MASTER")"
vrrp_prio_nginx1="$(printf '%s' "${instance_meta}" | jq -r '.nginx1.vrrp_priority // "101"' 2>/dev/null || printf '%s' "101")"
vrrp_role_nginx2="$(printf '%s' "${instance_meta}" | jq -r '.nginx2.vrrp_role // "BACKUP"' 2>/dev/null || printf '%s' "BACKUP")"
vrrp_prio_nginx2="$(printf '%s' "${instance_meta}" | jq -r '.nginx2.vrrp_priority // "100"' 2>/dev/null || printf '%s' "100")"

# Basic sanity checks
# for value in "${backend_ip}" "${monitoring_ip}" "${nginx2_private}" "${nginx1_private}" "${jump_ip}" "${eip_alloc_id}"; do
#   if [ -z "${value}" ] || [ "${value}" = "null" ]; then
#     echo "Missing required IP(s) in Terraform outputs. Run terraform apply first."
#     exit 1
#   fi
# done

cat > "${OUT_FILE}" <<EOF
[backend_nodes]
backend ansible_host=${backend_ip} ansible_user=ubuntu

[nginx_public]
nginx1 ansible_host=${nginx1_private} ansible_user=ubuntu

[nginx_private]
nginx2 ansible_host=${nginx2_private} ansible_user=ubuntu

[nginx:children]
nginx_public
nginx_private

[keepalived]
master ansible_host=${nginx1_private} ansible_user=ubuntu vrrp_role=${vrrp_role_nginx1} vrrp_priority=${vrrp_prio_nginx1}
backup ansible_host=${nginx2_private} ansible_user=ubuntu vrrp_role=${vrrp_role_nginx2} vrrp_priority=${vrrp_prio_nginx2}

[monitoring_nodes]
monitoring ansible_host=${monitoring_ip} ansible_user=ubuntu

[private_nodes]
backend
nginx2
monitoring
master
backup

[private_nodes:vars]
# We use ProxyCommand instead of ProxyJump to force the identity file into the jump hop
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ${SSH_KEY_FILE} -W %h:%p -q ubuntu@${jump_ip} -o StrictHostKeyChecking=no"'

[all:vars]
ansible_ssh_private_key_file=${SSH_KEY_FILE}
workload_path=../../../services
env_type=aws
vip_allocation_id=${eip_alloc_id}
EOF

echo "Generated ${OUT_FILE} using bastion jump host ${jump_ip}"
echo "Keepalived group added with VRRP role/priority from Terraform outputs (or sane defaults)."
echo "Private hosts use ProxyCommand through bastion."
