# LOMP Lite Recipe Contract (Repo-Only Baseline)

## Goal
- Define a local-only recipe contract for LOMP Lite planning.
- Output action plans only; do not execute host changes.

## Inputs (Inventory-Driven)
- Host file (`inventory/hosts/*.yml`):
  - `id`
  - `role`
  - `arch`
  - `resources`
  - `tailscale.ip`
- Hub file (`inventory/hosts/*.yml`):
  - `id`
  - `role`
  - `services.mariadb.port`
  - `services.redis.port`
  - `tailscale.ip`
- Site file (`inventory/sites/*.yml`):
  - `site_id`
  - `stack`
  - `topology`
  - `host_ref`
  - `hub_ref`
  - `db.name`
  - `db.user`
  - `redis.namespace`

## Required Runtime Flags
- `HZ_DRY_RUN`
  - `0`: reserved for future apply mode
  - `1`: print planned actions
  - `2`: print condensed plan artifacts only

## Contracted Subcommands
- `install`
- `status`
- `check`
- `upgrade`
- `backup`
- `restore`
- `uninstall`
- `diagnostics`

## Output Plan Sections
1. Preflight checks
- inventory reference validation result
- host/hub topology sanity checks

2. Web plan
- OLS + WP staged actions (host side)
- low-memory policy notes

3. Data plan
- MariaDB + Redis staged actions (hub side)
- network boundary notes for internal-only routing

4. Operations plan
- backup/restore checkpoints
- status/check/diagnostics command plan

5. Risk and rollback summary
- expected failure points
- rollback command placeholders

## Acceptance Checklist (Repo-Only)
- Contract document exists and is referenced by audit record.
- No host command execution paths are added in this phase.
- `make check` remains green.
