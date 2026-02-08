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

## Host Optional Keys
- `allow_from`
- `services`

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
- If `topology: standard`, `hub_ref` may be omitted.

## Validation Command
- `bash scripts/check/inventory_validate.sh`

## Strict Value Rules
- Host:
  - `role`: `host|hub`
  - `os`: `ubuntu-22.04|ubuntu-24.04`
  - `arch`: `x86_64|aarch64`
  - `tailscale.ip`: IPv4 format
  - `ssh.port`: numeric
- Site:
  - `stack`: `lomp|lnmp`
  - `topology`: `lite|standard`

## Error Output Format
- All validation failures use this normalized format:
  - `ERROR|file=<path>|code=<CODE>|message=<detail>`
- Common codes:
  - `MISSING_DIR`
  - `MISSING_HOST_FILES`
  - `MISSING_SITE_FILES`
  - `MISSING_KEY`
  - `EMPTY_VALUE`
  - `INVALID_VALUE`
  - `UNRESOLVED_REF`
