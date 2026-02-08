# LNMP Lite Inventory Example Notes

## Site File (`inventory/sites/site-lnmp-lite-a.yml`)
This sample is for LNMP Lite planning where web stack differs and shared hub/maintenance/security remain reused.

### Base Required Keys
- `site_id`
- `domain`
- `slug`
- `stack`
- `topology`
- `host_ref`
- `hub_ref`
- `db.name`
- `db.user`
- `redis.namespace`

### LNMP Web Stack Keys
- `web_stack.engine`
- `web_stack.tls_mode`
- `web_stack.app_runtime_profile`

## Usage
- Optional dry-run input override:
  - `SITE_FILE=inventory/sites/site-lnmp-lite-a.yml`
