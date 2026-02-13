# Project State Ledger (SSOT)

This file is the single source of truth for project progress.
Update this file via PR whenever work starts/finishes.

Last updated: YYYY-MM-DD
Owner: Pork-Belly

## Done
- (YYYY-MM-DD) <item>

## Doing
- (YYYY-MM-DD) <item> (PR: #<n>)

## Next
- <item>
- <item>

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
- <question>
