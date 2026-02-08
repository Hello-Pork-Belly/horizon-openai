# Hub Data Inventory Example Notes

## Site Hub Data File (`inventory/sites/site-hub-data-a.yml`)
This sample provides non-sensitive planning inputs for hub-side data service dry-run flows.

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

### Hub Data Planning Keys
- `hub_data.bind_interface`
- `hub_data.allowed_hosts`
- `hub_data.db_port`
- `hub_data.redis_port`
- `hub_data.backup_target`
- `hub_data.retention_count`

## Usage
- Optional dry-run input override:
  - `SITE_FILE=inventory/sites/site-hub-data-a.yml`

## Validation Rules
- `hub_ref` must map to `inventory/hosts/*.yml` id.
- `hub_data.allowed_hosts` values should map to host ids.
- `hub_data.bind_interface` should remain `tailscale0` for hub data service planning.
