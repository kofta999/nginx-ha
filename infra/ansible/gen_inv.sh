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

backend_ip="$(printf '%s' "${private_ips}" | jq -r '.backend.backend // empty')"
monitoring_ip="$(printf '%s' "${private_ips}" | jq -r '.monitoring.monitoring // empty')"
nginx1_private="$(printf '%s' "${private_ips}" | jq -r '.nginx.nginx1 // empty')"
nginx2_private="$(printf '%s' "${private_ips}" | jq -r '.nginx.nginx2 // empty')"

# Jump host: prefer nginx1 public IP, fallback nginx2 public IP
nginx1_public="$(printf '%s' "${public_ips}" | jq -r '.nginx1 // empty')"
nginx2_public="$(printf '%s' "${public_ips}" | jq -r '.nginx2 // empty')"

if [ -n "${nginx1_public}" ] && [ "${nginx1_public}" != "null" ]; then
  jump_ip="${nginx1_public}"
elif [ -n "${nginx2_public}" ] && [ "${nginx2_public}" != "null" ]; then
  jump_ip="${nginx2_public}"
else
  echo "No public nginx IP found. Cannot build ProxyJump inventory."
  exit 1
fi

# Basic sanity checks
for value in "${backend_ip}" "${monitoring_ip}" "${nginx2_private}" "${jump_ip}"; do
  if [ -z "${value}" ] || [ "${value}" = "null" ]; then
    echo "Missing required IP(s) in Terraform outputs. Run terraform apply first."
    exit 1
  fi
done

cat > "${OUT_FILE}" <<EOF
[backend_nodes]
backend ansible_host=${backend_ip} ansible_user=ubuntu

[nginx_public]
nginx1 ansible_host=${jump_ip} ansible_user=ubuntu

[nginx_private]
nginx2 ansible_host=${nginx2_private} ansible_user=ubuntu

[nginx:children]
nginx_public
nginx_private

[monitoring_nodes]
monitoring ansible_host=${monitoring_ip} ansible_user=ubuntu

[private_nodes]
backend
nginx2
monitoring

[private_nodes:vars]
# We use ProxyCommand instead of ProxyJump to force the identity file into the jump hop
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ${SSH_KEY_FILE} -W %h:%p -q ubuntu@${jump_ip} -o StrictHostKeyChecking=no"'

[all:vars]
ansible_ssh_private_key_file=${SSH_KEY_FILE}
workload_path=../../../services
EOF

echo "Generated ${OUT_FILE} using jump host ${jump_ip}"
echo "Private hosts use ProxyJump; public jump host connects directly."
