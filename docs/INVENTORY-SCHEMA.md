# Inventory Schema Baseline

## Paths
- `inventory/hosts/*.yml`
- `inventory/sites/*.yml`

## Host Required Keys
- `id`
- `role`
- `os`
- `arch`
- `resources`
- `tailscale`
- `ssh`

## Site Required Keys
- `site_id`
- `domain`
- `slug`
- `stack`
- `topology`
- `host_ref`
- `db`
- `redis`

## Reference Resolution Rules
- `site.host_ref` must resolve to an existing `hosts.id`.
- If `topology: lite`, `hub_ref` must be non-null and resolve to an existing `hosts.id`.

## Validation Command
- `bash scripts/check/inventory_validate.sh`
