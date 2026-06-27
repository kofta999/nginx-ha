variable "ssh_key_name" {
  description = "Existing AWS EC2 key pair name for SSH"
  type        = string
}

variable "ssh_key_file" {
  description = "Existing AWS EC2 key path for Ansible SSH access"
  type        = string
}
