# Project State Ledger (SSOT)

This file is the single source of truth for project progress.
Update this file via PR whenever work starts/finishes.

Last updated: 2026-02-15
Owner: Pork-Belly

## Done
- (2026-02-13) SSOT bootstrap
- (2026-02-15) T-004 CLI Skeleton (hz) (PR: #63)
- (2026-02-15) T-005 Recipe Runner (hz install) (PR: #64)

## Doing
- (2026-02-15) T-006 Inventory Integration (PR: #<TBD>)

## Next
- T-001 Auto-merge Enabler

## Current Focus
- Primary target: One-click installation system (recipes/ + inventory/)
- Required gates: `make ci` + audit PASS

## Known Risks / Watchlist
- Secrets leakage (logs/diagnostics/env)
- Vendor-neutral gate violations
- DB/Redis exposure (tailscale0-only)
- Backup/restore validity and evidence
- Idempotency / ownership boundaries
