# Project State Ledger (SSOT)

This file is the single source of truth for project progress.
Update this file via PR whenever work starts/finishes.

Last updated: 2026-02-15
Owner: Pork-Belly

## Done
- (2026-02-13) SSOT bootstrap
- (2026-02-13) Roles + Workflow solidification for SSOT execution

## Doing
- (2026-02-15) T-004 CLI Skeleton (hz) (PR: #<TBD>)

## Next
- T-001 Auto-merge Enabler (auto-enable auto-merge for eligible PRs)
- T-002 Repo Hygiene Plan (identify useless dirs/files; propose target structure)
- T-003 Repo Hygiene Execute (cleanup/archive/reorder per plan)

## Current Focus
- Primary target: One-click installation system (recipes/ + inventory/)
- Required gates: `make ci` + audit PASS

## Known Risks / Watchlist
- Secrets leakage (logs/diagnostics/env)
- Vendor-neutral gate violations
- DB/Redis exposure (tailscale0-only)
- Backup/restore validity and evidence
- Idempotency / ownership boundaries

## Open Questions
- None
