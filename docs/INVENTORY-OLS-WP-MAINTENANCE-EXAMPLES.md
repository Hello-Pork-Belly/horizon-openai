# OLS+WP Maintenance Inventory Example Notes

## Site Maintenance File (`inventory/sites/site-ols-wp-maint-a.yml`)
This sample extends the base OLS+WP site inventory with maintenance-oriented keys used for dry-run planning.

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

### Maintenance Planning Keys
- `maintenance.php_profile`
- `maintenance.swap_policy`
- `maintenance.scheduler_mode`
- `maintenance.backup_target`
- `maintenance.retention_count`
- `maintenance.site_health_target`

## Usage
- Default maintenance dry-run can use this file by setting:
  - `SITE_FILE=inventory/sites/site-ols-wp-maint-a.yml`

## Validation Rules
- `host_ref` and `hub_ref` must resolve to host ids in `inventory/hosts/*.yml`.
- `topology: lite` requires a non-null `hub_ref`.
