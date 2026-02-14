# Project State Ledger (SSOT)

This file is the single source of truth for project progress.
Update this file via PR whenever work starts/finishes.

Last updated: 2026-02-15
Owner: Pork-Belly

## Done
- (2026-02-13) SSOT bootstrap

## Doing
- (2026-02-15) T-001 Auto-merge Enabler (PR: #<TBD>)

## Next
- T-001b Align RULES.yml merge_policy/forbidden_paths with approved auto-merge workflow exception

## Current Focus
- Primary target: LOMP Lite v1 (hub + host)
- Required gates: `make ci` + audit PASS

## Known Risks / Watchlist
- Secrets leakage (logs/diagnostics/env)
- Vendor-neutral gate violations
- DB/Redis exposure (tailscale0-only)
- Backup/restore validity and evidence
- Idempotency / ownership boundaries

## Open Questions
- Should the `automerge` label be restricted further via repository label permissions/policy?
