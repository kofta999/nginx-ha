# Backend Role

This role prepares the backend host to run containerized application workloads from the local `services/` directory.

## What this role does

The role runs two task files in order:

1. `tasks/docker.yml`
   - Installs required system packages
   - Adds Docker apt GPG key
   - Adds Docker apt repository
   - Installs:
     - `docker-ce`
     - `docker-compose`
     - `python3-docker`

2. `tasks/workload.yml`
   - Copies workload files from controller to remote host using `ansible.posix.synchronize`
   - Starts the compose project with `community.docker.docker_compose_v2`
   - Forces image rebuild with `build: always`

## Variables

### Required

- `workload_path`  
  Source path on the Ansible controller to sync to `/opt` on the backend host.

### Used by modules/runtime

- Docker daemon available on target host (installed by this role)
- `rsync` available for synchronize workflow (required by `ansible.posix.synchronize`)

## Resulting state on target

- Workload files are present under `/opt` (for example `/opt/services`)
- Docker Compose project in `/opt/services` is brought to `present` state
- Images are rebuilt during deployment (`build: always`)

## Files and structure

- `tasks/main.yml`  
  Includes `docker.yml` and `workload.yml`
- `tasks/docker.yml`  
  Docker engine + compose installation
- `tasks/workload.yml`  
  Workload sync and compose deployment
- `handlers/main.yml`  
  Currently empty (no handlers defined)

## Example usage

```yaml
- name: Backend workload config
  hosts: backend
  become: true
  vars:
    backend_workload_path: "{{ playbook_dir }}/../../services"
  roles:
    - backend
```

## Run examples

Run only this role via the playbook tag:

```bash
ansible-playbook -i inventory.ini site.yml --tags backend
```

Or run the full site:

```bash
ansible-playbook -i inventory.ini site.yml
```

## Notes

- `community.docker.docker_compose_v2` uses `project_src: /opt/services`, so your synced directory is expected to contain `compose.yml` at that path.
