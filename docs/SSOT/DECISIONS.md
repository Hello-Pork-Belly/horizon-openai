# Decisions Log (SSOT)

Record any decision that changes behavior, contract, security, or workflow.
Format: date + decision + rationale + scope + links.

## 2026-02-13 — SSOT bootstrap
Decision:
- Establish SSOT files: STATE.md / DECISIONS.md / SPEC-TEMPLATE.md
Rationale:
- Prevent context drift in a medium-sized project.
Scope:
- Repository-wide process

## 2026-02-13 — Roles + Workflow solidification for SSOT execution
Decision:
- Establish role contracts under docs/SSOT/ROLES/.
- Enforce “Best Default, no ambiguity” as a mandatory Planner behavior.
- Allow auto-merge only when required checks pass and audit is PASS; no manual bypass of gates.
- Keep SSOT precedence and PR-only workflow as non-negotiable governance.
Rationale:
- Reduce execution ambiguity across Commander/Planner/Executor/Auditor handoffs.
- Standardize merge safety and prevent gate circumvention.
Scope:
- docs/SSOT/ROLES/*.md
- docs/SSOT/STATE.md
- docs/SSOT/DECISIONS.md
Links:
- PR: docs(ssot): add role contracts and bootstrap process ledger

## Template
### YYYY-MM-DD — <title>
Decision:
- <bullet>
Rationale:
- <bullet>
Scope:
- <paths/modules affected>
Links:
- PR #<n>, Issue #<n>
