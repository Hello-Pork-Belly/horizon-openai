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
- `bash scripts/check/inventory.sh`
- `bash scripts/check/inventory_test.sh`

## Validation
- check line format:
  - `CHECK inventory.<hosts|sites>.<relative_path> PASS|FAIL <reason>`
- result line format:
  - `RESULT inventory PASS=<n> FAIL=<n>`
- fatal error line format (unsupported yaml or inventory layout errors only):
  - `ERROR|file=<relative_path>|code=<CODE>|message=<english_detail>`
- inventory must not contain credential-like key names; use env/secret injection for sensitive data.

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
- Fatal/unsupported parse and layout failures use this normalized format:
  - `ERROR|file=<relative_path>|code=<CODE>|message=<english_detail>`
- Common fatal codes:
  - `INVENTORY_LAYOUT_ERROR`
  - `YAML_UNSUPPORTED_TAB`
  - `YAML_UNSUPPORTED_FEATURE`
