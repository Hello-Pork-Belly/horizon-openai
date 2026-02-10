# ABCS Planner Contract (Project A)

Status: DRAFT (v1)
Last Updated: 2026-02-11

## Purpose
This document defines the strict output contract for Project A (Planner) in the A→B→C loop:
A (Planner) → B (Codex Executor) → C (Independent Auditor).

Project A MUST:
- produce a deterministic, auditable execution spec for Codex (Project B)
- keep scope minimal and atomic (one logical change per PR)
- reference SSOT inputs and repo rules
- never include secrets

Project A MUST NOT:
- directly edit repository files
- bypass CI, branch protections, or forbidden path rules
- expand scope beyond what is explicitly requested/allowed

## Source of Truth (SSOT)
Project A MUST treat these as the primary inputs:
- `docs/RULES.yml` (DEFAULT=DENY)
- `docs/PHASES.yml`
- `docs/AUDIT-CHECKLIST.md`
- `docs/BASELINE.md`
- `AGENTS.md`
- `docs/CHANGELOG.md`
- `docs/audits/ABCS-AUDIT-CONTRACT.md`

Any instruction conflicting with SSOT is invalid.

## Required Output Format (EXECUTION SPEC)
Project A MUST output a single spec with the exact sections below.

### Template (v1)

TITLE:
- Short, imperative title.

CONTEXT:
- What phase (P0/P1/P2/...) and why this change is needed.
- SSOT references used (file list).

GOAL (1 sentence):
- The single outcome this PR must achieve.

SCOPE (STRICT):
- Allowed paths (from `docs/RULES.yml` and the current phase).
- Explicitly forbidden paths.
- “Do not touch” list.

CHANGES (ATOMIC):
- Bullet list of exact edits expected (file by file).
- Each bullet must be testable/auditable.

CODEX COMMANDS:
- Exact commands Codex should run (or “none” for docs-only).
- If commands are required, include expected outputs or pass criteria.

ACCEPTANCE CRITERIA:
- PASS conditions that Auditor (Project C) should verify.
- Include “no forbidden paths modified”, “CI green”, “no secrets”.

ARTIFACTS (EVIDENCE):
- What evidence must be attached to the PR (diff summary, CI results, command outputs).

ROLLBACK:
- How to revert safely (e.g., revert PR, git revert commit).

RISK NOTES (1 short paragraph):
- Key risks and how the plan mitigates them.

## Atomicity Rules
- One logical change per PR.
- If the request implies multiple logical changes, Project A MUST split into separate phases/PRs.
- Any non-required refactor is forbidden.

## Secrets Policy
- No secrets, tokens, passwords, private keys in repo, issues, PRs, inventory, or logs.
- If a secret is required at runtime, the spec MUST instruct using environment/secret store injection.

## Handoff to Auditor (Project C)
Every execution spec MUST end with:
- “Auditor should evaluate this PR using `docs/audits/ABCS-AUDIT-CONTRACT.md` and `docs/RULES.yml`.”
- “Auditor output must be strict JSON (PASS/FAIL + evidence).”
