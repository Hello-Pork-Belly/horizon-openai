# SPEC: T-002 Repo Hygiene Plan

Status: PLAN-ONLY (no file moves, no deletions)
Date: 2026-02-15
Owner: Planner (GPT)
Priority: High

Context
- Repository currently mixes legacy scripts, upstream snapshots, and multiple top-level buckets.
- Project goal: "One-click installation system" with focus on `recipes/` and `inventory/`.

Inputs (source of truth for this plan)
- Current top-level structure observed in repository root:
  - .codex/, .github/, bin/, docs/, inventory/, modules/, recipes/, scripts/, skills/, upstream/oneclick
  - Root files: .gitignore, AGENTS.md, LICENSE, Makefile, README.md, VERSION
- NOTE: Subdirectory file listings will be enumerated during T-003 execution via `git ls-tree -r --name-only HEAD`.
  This plan classifies at directory / pattern granularity and defines strict target state.

------------------------------------------------------------
Section 1: Classification (KEEP / ARCHIVE / DELETE)
------------------------------------------------------------

KEEP (core to one-click system or governance)
- docs/
  - KEEP all governance and SSOT docs.
- inventory/
  - KEEP; this is a core artifact for node definitions and profiles.
- recipes/
  - KEEP; primary one-click entry points and orchestration.
- modules/
  - KEEP for now; assumed reusable install units used by recipes.
- bin/
  - KEEP; treat as stable user-facing entry points (CLI).
- scripts/
  - KEEP but RECLASSIFY: split into:
    - lib/ (shared bash library code)
    - tools/ (repo-maintenance utilities)
  - Action in T-003: move code accordingly, but NOT in this task.
- .github/
  - KEEP; CI and governance workflows.
- .codex/ and skills/
  - KEEP; developer tooling / skill packs used by agents.
- Root governance files
  - KEEP: README.md, AGENTS.md, Makefile, VERSION, LICENSE, .gitignore

ARCHIVE (move into archive/ as read-only snapshots; no longer active path)
- upstream/
  - ARCHIVE entire `upstream/` into `archive/upstream-YYYYMMDD/`
  - Rationale: keep provenance/history but remove from active working set.
- Legacy oneclick snapshot inside upstream/oneclick
  - ARCHIVE by default unless verified as current production entry point.

DELETE (safe to remove once confirmed unused; plan-only list)
- Any duplicated "old oneclick" installers that are fully superseded by recipes/modules.
- Any temporary artifacts (e.g. *.bak, *~ , *.tmp, .DS_Store) if found in tree.
- Any vendor-specific or environment-specific notes that violate vendor-neutral policy (must be replaced with neutral docs first).
NOTE: Actual file-level DELETE candidates must be enumerated in T-003 with exact paths + evidence (grep references + last-use).

------------------------------------------------------------
Section 2: Target Structure (desired final tree)
------------------------------------------------------------

Target goals:
- Make `recipes/` + `inventory/` the product spine.
- Make stable entry points explicit (`bin/`).
- Separate reusable bash libraries (`lib/`) from operational tools (`tools/`).
- Quarantine legacy/provenance into `archive/`.
- Keep governance docs in `docs/` and SSOT under `docs/SSOT/`.

Desired tree (high-level):

.
├── bin/                        # stable entrypoints (user-facing)
├── docs/
│   ├── SSOT/
│   │   ├── ROLES/
│   │   ├── specs/
│   │   ├── DECISIONS.md
│   │   └── STATE.md
│   └── (baseline, audit, scope, etc.)
├── inventory/                  # node inventory + profiles
├── recipes/                    # one-click orchestrations
├── modules/                    # reusable install modules (called by recipes)
├── lib/                        # bash libraries (sourced by bin/recipes/modules)
├── tools/                      # repo maintenance tools (lint, gates, helpers)
├── tests/                      # smoke/integration tests (CI friendly)
├── archive/                    # quarantined legacy content
│   └── upstream-YYYYMMDD/
│       └── oneclick/
├── .github/
├── .codex/
└── skills/

Mapping rules (strict):
- Any bash file that is sourced by other bash => lib/
- Any operator/admin helper not part of product path => tools/
- Any third-party snapshot / historical copy => archive/
- Any "oneclick" product path must be in recipes/ + inventory/ (+ modules/) and exposed via bin/

------------------------------------------------------------
Section 3: Rationale (why move/archive/delete)
------------------------------------------------------------

1) Reduce cognitive load:
- Top-level folders should communicate system boundaries. Active product path must be obvious:
  recipes + inventory (+ modules) + bin.

2) Prevent accidental execution of legacy code:
- Upstream snapshots are valuable for provenance but dangerous in active tree because they look runnable.
  Archiving removes ambiguity.

3) Enforce stable interfaces:
- `bin/` is the only supported entry path for operators; everything else is internal.

4) Make CI/testing scalable:
- `tests/` becomes the home for deterministic checks. `tools/` hosts repo checks without polluting product code.

5) Keep governance as SSOT:
- docs/SSOT remains the authoritative process ledger.

Execution boundary (explicit):
- This task produces plan only.
- T-003 will:
  - generate full file list via `git ls-tree -r --name-only HEAD`
  - map each path to KEEP/ARCHIVE/DELETE with evidence
  - propose atomic commits and rollback steps per move batch
  - update CI only if required and explicitly allowed
