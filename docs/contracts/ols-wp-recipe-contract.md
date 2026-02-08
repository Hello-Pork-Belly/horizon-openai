# OLS WP Recipe Contract (Repo-Only)

## Goal
- Define a local dry-run recipe contract for OLS + WP planning.
- Print plan and intended file/command actions only.

## Inputs (Inventory-Driven)
- Host inventory:
  - `id`
  - `role`
  - `os`
  - `arch`
  - `resources`
  - `tailscale.ip`
- Site inventory:
  - `site_id`
  - `domain`
  - `slug`
  - `stack`
  - `topology`
  - `host_ref`
  - `db.name`
  - `db.user`
  - `redis.namespace`

## Dry-Run Semantics
- `HZ_DRY_RUN=1`: detailed action plan.
- `HZ_DRY_RUN=2`: compact artifact-oriented plan.
- `HZ_DRY_RUN=0`: reserved, still plan-only in repo baseline.

## Contracted Subcommands
- `install`
- `status`
- `check`
- `upgrade`
- `backup`
- `restore`
- `uninstall`
- `diagnostics`

## Planned Output Sections
1. Preflight and inventory checks
2. OLS and WP staged file/config plan
3. Runtime limits and cron staged plan
4. Backup/restore staged plan
5. Rollback checklist
