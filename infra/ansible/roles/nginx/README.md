# nginx Role

Configures NGINX as a reverse proxy/load-balancer node and installs the NGINX Prometheus exporter as a `systemd` service.

## What this role does

- Installs `nginx`
- Enables and starts the `nginx` service
- Creates TLS materials under `/etc/nginx/ssl`:
  - private key: `/etc/nginx/ssl/key.pem`
  - CSR: `/etc/nginx/ssl/cert.csr`
  - self-signed cert: `/etc/nginx/ssl/cert.pem`
- Ensures `/etc/nginx/conf.d` exists
- Copies role-managed NGINX configs:
  - `files/nginx.conf` -> `/etc/nginx/nginx.conf` (validated with `nginx -t -c %s`)
  - `files/conf.d/*` -> `/etc/nginx/conf.d/`
- Installs `nginx-prometheus-exporter` binary as:
  - `/usr/local/bin/nginx-node-exporter`
- Installs and enables `systemd` unit:
  - `/etc/systemd/system/nginx-node-exporter.service`
- Reloads `systemd` daemon and starts exporter service

## Files used by this role

- `files/nginx.conf`
- `files/conf.d/default.conf`
- `files/conf.d/upstream.conf`
- `files/conf.d/metrics.conf`
- `files/nginx-node-exporter.service`

## Handlers

- `Reload nginx`  
  Triggered when `nginx.conf` changes and validated successfully.

## Requirements

Collections/modules used:

- `community.crypto`
  - `openssl_privatekey`
  - `openssl_csr`
  - `x509_certificate`

Target host assumptions:

- Debian/Ubuntu-family host with `apt`
- `systemd` available

## Exporter configuration

Exporter service runs with:

`nginx-prometheus-exporter --nginx.scrape-uri=http://127.0.0.1:8080/stub_status`

Make sure your NGINX config exposes `stub_status` on that endpoint (typically via `metrics.conf`).

## Variables

This role currently does not expose tunables in `defaults/main.yml`; paths and exporter version are hardcoded in tasks.

Notable hardcoded value:

- Exporter release: `v1.5.1`

If you want customization, common next step is to add variables for:

- exporter version/download URL
- scrape URI
- cert common name and validity period

## Example usage

From `site.yml` this role is applied to the `nginx` group:

```yaml
- name: Nginx hosts config
  hosts: nginx
  become: true
  tags:
    - nginx
  roles:
    - nginx
```

Run only this role:

```bash
ansible-playbook -i inventory.ini site.yml --tags nginx
```

## Verification

After applying:

```bash
sudo nginx -t
systemctl status nginx --no-pager
systemctl status nginx-node-exporter --no-pager
curl -s http://127.0.0.1:8080/stub_status
curl -s http://127.0.0.1:9113/metrics | head
```

## Notes

- SSL key/cert are self-signed and suitable for lab/dev usage.
- For production, replace with trusted cert management and tighten file permissions/policies.