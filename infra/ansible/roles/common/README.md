# common role

Installs baseline host monitoring by configuring Node Exporter on all hosts.

## What this role does

This role currently performs one task:

- Includes the community role `prometheus.prometheus.node_exporter` to install and configure Node Exporter.

That gives each host a Prometheus metrics endpoint (typically on port `9100`) for system-level metrics like CPU, memory, filesystem, and network.

## Where it is used

In `site.yml`, this role is applied to:

- `hosts: all`
- `become: true`
- `tags: [common]`

So every VM in your inventory gets Node Exporter.

## Requirements

- Ansible collections/roles available in your environment:
  - `prometheus.prometheus` (for `node_exporter` role)
- Target hosts must be reachable via SSH and allow privilege escalation (`become: true`).

## Variables

This role does not define project-specific defaults in `defaults/main.yml`.

You can still tune Node Exporter behavior by passing variables supported by `prometheus.prometheus.node_exporter` (for example listen address, enabled collectors, extra flags) via inventory/group vars/host vars.

## Handlers

No handlers are defined by this role.

## Dependencies

- `prometheus.prometheus.node_exporter` (included from `tasks/main.yml`)

## Example usage

```yaml
- name: Common config
  hosts: all
  become: true
  roles:
    - common
```

## Run only this role

From `infra/ansible`:

```bash
ansible-playbook -i inventory.ini site.yml --tags common
```

## Verification

After running, verify Node Exporter is up on a target host:

```bash
systemctl status node_exporter
curl -s http://127.0.0.1:9100/metrics | head
```

Or from another host with network access:

```bash
curl -s http://<target-host-ip>:9100/metrics | head
```
