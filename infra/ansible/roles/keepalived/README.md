# keepalived role

Configures HA failover for the two NGINX nodes using VRRP via `keepalived`, with an NGINX health-check script that affects priority.

## What this role does

- Installs `keepalived`
- Creates a dedicated system user: `keepalived_script`
- Deploys health-check script to:
  - `/usr/local/bin/check_nginx.sh`
- Ensures `keepalived` service is enabled and running
- Renders and installs config from template:
  - `templates/keepalived.conf.j2` -> `/etc/keepalived/keepalived.conf`
- Restarts `keepalived` when config changes (handler)

## Files in this role

- `tasks/main.yml`
- `handlers/main.yml`
- `templates/keepalived.conf.j2`
- `files/check_nginx.sh`

## Required variables

These variables are used by `templates/keepalived.conf.j2` and must be available in inventory/group vars/host vars:

- `vrrp_role`  
  Expected values: `MASTER` or `BACKUP`
- `keepalived_interface`  
  Network interface used for VRRP advertisements (example: `eth1`)
- `virtual_router_id`  
  Integer VRID shared by nodes in same VRRP instance
- `vrrp_priority`  
  Higher value wins MASTER election
- `advertise_interval_secs`  
  VRRP advert interval in seconds
- `keepalived_auth_pass`  
  VRRP auth password
- `keepalived_vip`  
  Virtual IP in CIDR-like format expected by keepalived (example: `192.168.56.15/24`)

## Inventory pattern used in this project

In this project, the role is applied to the `keepalived` host group, and per-node role/priority are set in inventory:

- `master` host with `vrrp_role=MASTER`, higher `vrrp_priority`
- `backup` host with `vrrp_role=BACKUP`, lower `vrrp_priority`

Example shape (illustrative):

- node A: `MASTER`, priority `101`
- node B: `BACKUP`, priority `100`

## Health-check behavior

The template config defines:

- `global_defs` with script security enabled
- `vrrp_script check_nginx` calling `/usr/local/bin/check_nginx.sh`
- `track_script check_nginx` under `vrrp_instance`

If NGINX health check fails repeatedly, VRRP weight is reduced (as defined in template), allowing failover to the backup node.

## Handler

- `Restart keepalived`  
  Triggered when `/etc/keepalived/keepalived.conf` changes.

## Example play usage

This role is already wired in `site.yml` as:

- play name: **Keepalived hosts config**
- hosts: `keepalived`
- become: `true`
- roles:
  - `keepalived`

## Run commands

From `infra/ansible`:

- Run only this role (via tag):
  `ansible-playbook -i inventory.ini site.yml --tags keepalived`
- Run against keepalived hosts limit:
  `ansible-playbook -i inventory.ini site.yml --limit keepalived`

## Validation tips

After applying role on a node:

- Service status:
  `systemctl status keepalived`
- Effective config:
  `cat /etc/keepalived/keepalived.conf`
- VIP presence:
  `ip a | grep -F "<your_vip_without_mask>"`
- Logs:
  `journalctl -u keepalived -n 100 --no-pager`
