# monitoring role

Configures observability on the `monitoring` host in this project.

At the moment, this role actively installs/configures **Grafana** and provisions dashboards from the repository.  
Prometheus setup is present in the task file as commented example blocks, but is not currently enabled by default.

## What this role does

- Imports the Galaxy role `grafana.grafana.grafana`
- Sets Grafana admin password from `grafana_admin_password`
- Creates a default Prometheus datasource pointing to:
  - `http://localhost:9090`
- Provisions dashboards from:
  - `roles/monitoring/files/dashboards`

## Role tasks

Defined in `tasks/main.yml`:

1. `Setup Grafana` via:
   - `ansible.builtin.import_role: grafana.grafana.grafana`
2. Passes these vars to the imported role:
   - `grafana_ini.security.admin_password`
   - `grafana_datasources` (Prometheus datasource)
   - `grafana_dashboards_dir`

There are no active handlers in this role.

## Variables

### Required

- `grafana_admin_password`  
  Used as Grafana admin password (`grafana_ini.security.admin_password`).

### Optional / currently unused in this role

- No defaults are defined in `defaults/main.yml`.
- Any extra Grafana tuning can be added by extending vars in playbooks/group_vars.

## Files used by this role

- `roles/monitoring/tasks/main.yml`
- `roles/monitoring/files/dashboards/nginx-ha-dashboard-v1.json`
- `roles/monitoring/files/dashboards/nginx-ha-dashboard-v2.json`

## Dependencies

Collection/role dependency:

- `grafana.grafana.grafana` (Ansible Galaxy role)

(If you enable Prometheus tasks later, you will also need `prometheus.prometheus.prometheus`.)

## Example usage

This project already uses the role in `site.yml`:

- Play name: `Monitoring host config`
- Hosts: `monitoring`
- Tags: `monitoring`

Equivalent snippet:

```yaml
- name: Monitoring host config
  hosts: monitoring
  become: true
  roles:
    - monitoring
```

## Run only this role

From `infra/ansible`:

```bash
ansible-playbook -i inventory.ini site.yml --tags monitoring
```

## Notes specific to this project

- Inventory defines `monitoring` as `192.168.56.14`.
- Datasource URL is local (`localhost:9090`), so Prometheus must run on the same VM if you keep this value.
- If Prometheus runs elsewhere, update datasource URL accordingly.
- The commented Prometheus scrape examples in `tasks/main.yml` already include targets for:
  - node exporter on all hosts (`:9100`)
  - nginx exporter on nginx hosts (`:9113`)
  - auth service (`backend:3000`)
  - products service (`backend:4000`)