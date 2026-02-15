# Recipes Catalog

This file lists recipes currently available in this repository (with `./bin/hz` as the only entrypoint).

Common commands:
- List: `./bin/hz recipe list`
- Dry-run: `HZ_DRY_RUN=1 ./bin/hz recipe <name> install`
- Execute: `./bin/hz recipe <name> install`

Current recipes (roadmap-aligned):
- security-host: baseline host hardening
- ols-wp: OpenLiteSpeed + WordPress stack
- ols-wp-maintenance: WordPress maintenance actions (action selected via env)
- lomp-lite: lightweight OLS/MariaDB/PHP
- lnmp-lite: lightweight Nginx/MariaDB/PHP
- hub-data: hub data layer (Redis/MariaDB)
- hub-main: hub control layer (Nginx dashboard + connectivity checks)
- mail-gateway: outbound mail gateway (msmtp/postfix)
- backup-rclone: rclone backup (S3-compatible object storage)

Notes:
- Every recipe defines its contract in `recipes/<name>/contract.yml`.
- CI only runs dry-run. Perform real installation on target nodes.
