# LOMP-Lite — Phase 1 Scope

## In Scope
- EN-first menu flow for LOMP-Lite (CN secondary/optional in Phase 1)
- Engine installation for OLS + WP core
- Minimal baseline tuning that is proven (real file edits)
- Security/Hardening flow must be wired and verified
- PHP worker / concurrency limits by RAM tier (OLS + LSPHP/LSAPI) with `verify` output

## Out of Scope (Phase 1)
- Full English/Chinese parity
- Multi-node / Hub mode
- Media/Net/Ops expansions not required for LOMP-Lite completion

## Acceptance
- Fresh VM run succeeds
- Re-run is idempotent
- Site Health meets target for low-spec tier
- Security checklist passes
- `verify` shows effective PHP worker/concurrency limits (values + config paths) and services are reloaded/restarted
