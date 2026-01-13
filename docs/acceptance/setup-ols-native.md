# Acceptance: OLS Native Engine Setup

## Scope
- Engine script: `scripts/web/setup_ols_native.sh`
- Expected config path (override with `OLS_CONF`): `/usr/local/lsws/conf/httpd_config.conf`

## Preconditions
- Run as root. Use sudo with explicit env (no `sudo -E`).
- Provide `OLS_ADMIN_PASS` via environment (the script does not prompt or print secrets).

## Dry Run Example
```bash
sudo OLS_ADMIN_PASS='example-only' DRY_RUN=1 bash scripts/web/setup_ols_native.sh
```

## Apply Example
```bash
sudo OLS_ADMIN_PASS='example-only' bash scripts/web/setup_ols_native.sh
```

## Verify Configuration Changes
1) Inspect current values before running (or to confirm after):
```bash
sudo grep -nE '^[[:space:]]*(maxConnections|instances)([[:space:]]|$)' /usr/local/lsws/conf/httpd_config.conf
```

2) On hosts with < 1900 MB RAM, confirm values are set to 10:
```bash
sudo grep -nE '^[[:space:]]*(maxConnections|instances)([[:space:]]|$)' /usr/local/lsws/conf/httpd_config.conf
```

3) If defaults were missing on higher-memory hosts, confirm the keys were appended.
```bash
sudo grep -nE '^[[:space:]]*(maxConnections|instances)([[:space:]]|$)' /usr/local/lsws/conf/httpd_config.conf
```

## Notes
- The script creates a one-time backup at `/usr/local/lsws/conf/httpd_config.conf.bak` when it needs to edit or append keys.
- Defaults used when keys are missing on higher-memory systems: `maxConnections 2000`, `instances 35`.
