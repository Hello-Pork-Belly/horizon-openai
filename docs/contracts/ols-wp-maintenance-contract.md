# OLS+WP Maintenance Contract (Repo-Only)

## Scope
This contract defines local planning requirements for OLS+WP lifecycle maintenance.
All actions are represented as dry-run plans only.

## Permission and Directory Safety
- Require explicit owner/group targets for web root and runtime directories.
- Require least-privilege mode targets for writable paths.
- Require path validation before any planned file mutation.
- Dry-run output must list directory path, owner target, and mode target.

## Certificate Renewal
- Define renewal precheck plan and postcheck plan.
- Dry-run output must include staged renewal command list and validation checklist.
- Include rollback checklist if renewal validation fails.

## PHP Concurrency and Resource Limits
- Define per-RAM-tier target caps for worker count and process concurrency.
- Define CPU and memory guardrail targets for runtime pool config.
- Dry-run output must list selected tier and resulting limits.

## Swap Policy
- Define swap presence checks and target size policy by RAM tier.
- Dry-run output must include whether swap create/resize is planned.

## Scheduler Policy (cron/WP-cron)
- Define whether platform cron is enabled and app-level scheduler mode.
- Dry-run output must include planned schedule entries and disable/enable flags.

## Backup and Restore Drill
- Define backup scope: app files, database artifacts, and config snapshots.
- Define restore drill scope and validation checkpoints.
- Storage target naming must remain neutral (`rclone remote`, `cloud drive target`).
- Dry-run output must include retention plan and verification steps.

## Site Health Targets
- Define target checks for HTTP health, runtime status, scheduler status, and backup freshness.
- Define pass/fail criteria for each check item.
- Dry-run output must include check list and target thresholds.

## Required Dry-Run Sections
1. `plan.preflight`
2. `plan.permissions`
3. `plan.certificate`
4. `plan.php_limits`
5. `plan.swap`
6. `plan.scheduler`
7. `plan.backup_restore`
8. `plan.site_health`
9. `plan.rollback`
