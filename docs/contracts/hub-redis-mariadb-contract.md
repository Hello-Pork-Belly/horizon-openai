# Hub Redis+MariaDB Contract (Repo-Only)

## Scope
This contract defines local dry-run planning requirements for hub-side data services.
All actions are plan-only outputs.

## Network Boundary
- Service reachability must be limited to `tailscale0`.
- Required service ports: `3306` (MariaDB) and `6379` (Redis).
- Public interface access to these ports must remain blocked.
- Dry-run output must show bind interface target and allowed source list.

## Access Policy
- Host allowlist must come from inventory host references (`allow_from`).
- Dry-run output must list allowed host refs and resolved tailscale IP targets.

## Tenant Isolation
- one site = one database
- one site = one database user with least privilege
- Redis namespace isolation per site
- Dry-run output must include generated naming plan and privilege scope.

## Backup and Restore Drill
- Define backup artifacts for database dumps and Redis snapshots.
- Define restore validation flow to isolated test targets.
- Storage target naming must remain neutral (`rclone remote`, `cloud drive target`).
- Dry-run output must include retention and restore checks.

## Required Dry-Run Sections
1. `plan.preflight`
2. `plan.network_boundary`
3. `plan.allowlist`
4. `plan.tenant_db`
5. `plan.tenant_redis`
6. `plan.backup_restore`
7. `plan.rollback`
