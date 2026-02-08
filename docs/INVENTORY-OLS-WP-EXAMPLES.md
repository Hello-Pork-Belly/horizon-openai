# OLS+WP Inventory Example Notes

## Host File (`inventory/hosts/host-ols-wp-a.yml`)
Required keys used by local checks and recipe dry-run:
- `id`
- `role`
- `os`
- `arch`
- `resources`
- `tailscale.ip`
- `ssh.user`
- `ssh.port`

## Hub File (`inventory/hosts/hub-ols-wp-a.yml`)
Required keys used by local checks and recipe dry-run:
- `id`
- `role`
- `os`
- `arch`
- `allow_from`
- `services.mariadb.port`
- `services.redis.port`

## Site File (`inventory/sites/site-ols-wp-a.yml`)
Required keys used by local checks and recipe dry-run:
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

## Reference Rules
- `host_ref` and `hub_ref` must resolve to `inventory/hosts/*.yml` `id` values.
- For `topology: lite`, `hub_ref` must be non-null.
