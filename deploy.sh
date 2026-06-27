#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${ROOT_DIR}/infra/ansible"
TF_DIR="${ROOT_DIR}/infra/terraform"

print_header() {
  echo "========================================"
  echo " nginx-ha deployment helper"
  echo "========================================"
}

run_local() {
  echo
  echo "[local] Starting Vagrant machines..."
  cd "${ROOT_DIR}"
  vagrant up

  echo
  echo "[local] Running Ansible playbook with local inventory..."
  cd "${ANSIBLE_DIR}"
  ansible-playbook -i inventory.ini site.yml

  echo
  echo "[local] Done."
  echo "Tip: Re-run specific role with tags, e.g.:"
  echo "  ansible-playbook -i inventory.ini site.yml --tags nginx"
}

run_aws() {
  echo
  echo "[aws] This will:"
  echo "  1) terraform apply"
  echo "  2) run ansible-playbook against AWS hosts"
  echo

  read -r -p "AWS EC2 key pair name [kofta]: " SSH_KEY_NAME
  SSH_KEY_NAME="${SSH_KEY_NAME:-kofta}"

  read -r -p "Path to local private key PEM [/home/${USER}/Downloads/${SSH_KEY_NAME}.pem]: " SSH_KEY_FILE
  SSH_KEY_FILE="${SSH_KEY_FILE:-/home/${USER}/Downloads/${SSH_KEY_NAME}.pem}"

  if [[ ! -f "${SSH_KEY_FILE}" ]]; then
    echo "ERROR: SSH key file not found: ${SSH_KEY_FILE}"
    exit 1
  fi

  chmod 400 "${SSH_KEY_FILE}" || true

  echo
  echo "[aws] Running terraform init/apply..."
  cd "${TF_DIR}"
  terraform init
  terraform apply --auto-approve -var="ssh_key_name=${SSH_KEY_NAME}"

  echo
  read -r -p "Proceed with ansible-playbook on AWS? [y/N]: " CONFIRM
  CONFIRM="${CONFIRM:-N}"
  if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
    # Navigating explicitly ensures Ansible finds hosts.yml and site.yml
    terraform apply --auto-approve -var="ssh_key_name=${SSH_KEY_NAME}" -invoke=action.ansible_playbook_run.ansible
    echo
    echo "[aws] Done."
  else
    echo "[aws] Skipped playbook run."
  fi
}

main() {
  print_header
  echo
  echo "Choose deployment target:"
  echo "  1) local (Vagrant + inventory.ini)"
  echo "  2) aws   (Terraform + Ansible Playbook Action)"
  echo
  echo "Tips:"
  echo " - Local is fastest for iteration/debug."
  echo " - AWS requires a valid EC2 key pair and matching local private key."
  echo

  read -r -p "Enter choice [1 or 2]: " TARGET_CHOICE

  case "${TARGET_CHOICE}" in
    1)
      run_local
      ;;
    2)
      run_aws
      ;;
    *)
      echo "Invalid selection. Exiting."
      exit 1
      ;;
  esac
}

main
