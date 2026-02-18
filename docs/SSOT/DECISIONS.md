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
Links:
- PR #<n>, Issue #<n>

## 2026-02-15 — D-001 Auto-merge Strategy
Decision:
- Add a GitHub Actions workflow that enables GitHub Auto-merge only when a PR is labeled `automerge`.
- Implementation uses `gh pr merge --auto --squash` to toggle auto-merge; it does not force-merge or bypass checks.
- Enforce gatekeeping in workflow: allow only actors with repo permission `write|maintain|admin` to trigger enablement.

Rationale:
- Reduce manual toil (“Enable auto-merge” click) while keeping strict quality gates: Branch Protection + required checks still decide when/if merge happens.
- Use `pull_request_target` on `labeled` to obtain write permissions safely without checking out or executing untrusted PR code.
- Dual gating (sender association + API permission check) reduces risk of unintended enablement.

Scope:
- .github/workflows/auto-merge.yml
- docs/SSOT/DECISIONS.md
- docs/SSOT/STATE.md

Assumptions:
- Repository setting “Allow auto-merge” is enabled.
- Branch Protection requires at least the `ci` check on the target branch.

Risks / Notes:
- SSOT rules currently list `.github/workflows/**` as forbidden and `auto_merge_allowed: false` in RULES.yml; this task is an explicitly approved exception via task allowlist. A follow-up task (T-001b) must reconcile RULES.yml to prevent audit ambiguity.

Rollback:
- Delete `.github/workflows/auto-merge.yml` and revert this decision entry.

Links:
- PR #<n>, Issue #<n>

## 2026-02-18 — D-008: SSOT reality alignment (phase truth + workflow policy wording)

Decision:
- Declare `docs/PHASES.yml` as the only authoritative phase truth source.
- Mark `docs/SSOT/PHASES.md` as deprecated mirror guidance only.
- Align `docs/RULES.yml` wording with repository reality: workflows may exist and run; workflow file edits remain restricted unless explicitly allowlisted.

Rationale:
- Remove dual-truth drift between phase docs.
- Remove policy wording ambiguity against actual `.github/workflows/**` usage.

Scope:
- docs/PHASES.yml (truth reference, unchanged content)
- docs/SSOT/PHASES.md
- docs/RULES.yml
- docs/SSOT/STATE.md

Links:
- PR: <fill-after-pr-created>

## Template
### YYYY-MM-DD — <Decision Title>
Decision:
- <bullet>
Rationale:
- <bullet>
Scope:
- <paths/modules affected>
Links:
- PR #<n>, Issue #<n>

## 2026-02-15 — D-002: Directory Structure Standard

Decision:
- Adopt a strict repository directory standard centered on the "one-click installation system":
  - Active product spine: `recipes/` + `inventory/` (+ `modules/`)
  - Stable operator entrypoints: `bin/`
  - Shared bash libraries: `lib/`
  - Repo maintenance utilities: `tools/`
  - Quarantined legacy/provenance: `archive/` (including `upstream/`)
  - Tests: `tests/`
- Treat `upstream/` as legacy snapshot content and plan to move it under `archive/` during execution (T-003), unless proven to be current production entrypoint.

Rationale:
- Reduce ambiguity and prevent accidental use of legacy code by separating “active product” from “historical snapshot”.
- Improve maintainability and CI/test ergonomics by separating entrypoints, libraries, and tools.

Scope:
- docs/SSOT/specs/T-002-hygiene-plan.md (plan)
- Future execution task(s): T-003 (moves/deletes with evidence and rollback)

Assumptions:
- This plan classifies primarily at directory/pattern level; exact file-level mapping will be generated in T-003 using `git ls-tree -r --name-only HEAD`.

Risks:
- Misclassification risk exists until the full tree is enumerated; therefore DELETE actions are prohibited until T-003 provides evidence.

Links:
- Task: T-002 Repo Hygiene Plan

## 2026-02-15 — D-004: CLI Architecture

Decision:
- Standardize `bin/hz` as the single user-facing entry point (dispatcher only).
- Move shared CLI behavior (logging, usage, repo root, version read, contract runner, check runner) into `lib/cli_core.sh`.
- Keep operational logic in `tools/` or existing runners referenced by contracts; `hz` only dispatches.

Rationale:
- Ensure a single, stable interface for “one-click” operations without duplicating logic.
- Improve maintainability by separating interface (bin) from implementation (lib/tools).
- Preserve existing contract-based module/recipe execution while adding required top-level subcommands: help/version/check/install.

Scope:
- bin/hz
- lib/cli_core.sh

Assumptions:
- `VERSION` remains the authoritative project version file.
- Repository check runner exists at `tools/check/run.sh` after hygiene, or `scripts/check/run.sh` before hygiene; `hz check` will prefer tools/ when present.

Links:
- Task: T-004 CLI Skeleton (hz)

## 2026-02-15 — D-005: Contract-First Execution

Decision:
- Implement `hz install <recipe>` as contract-first execution:
  - Require `recipes/<name>/contract.yml` and `recipes/<name>/run.sh` to exist.
  - Parse `required_env` from `contract.yml` (minimal YAML subset) and verify variables are set before running `run.sh`.
  - If validation fails, abort with exit code 1 and DO NOT execute `run.sh`.

Rationale:
- `hz` must be a safety airbag: prevent blind execution on an unprepared environment.
- Avoid complex dependencies; use pure-bash parsing for a strict, well-defined subset.

Scope:
- lib/recipe_loader.sh (new)
- bin/hz (install path updated)

Assumptions:
- `contract.yml` expresses env requirements via `required_env` (inline list or block list), optionally under `inputs`.
- Missing `contract.yml` is treated as a hard error (safer default).

Links:
- Task: T-005 Recipe Runner (hz install)

## 2026-02-15 — D-006: Inventory Loading Strategy

Decision:
- Add `lib/inventory.sh` providing `inventory_load_vars(hostname)` to export flat inventory YAML keys as environment variables.
- Precedence:
  - YAML merge: Global then Host (Host overrides Global).
  - Shell environment overrides YAML (never overwrite an already-set env var).

Parsing:
- Prefer python3; use PyYAML when present, otherwise a strict flat-line parser.
- Only accept flat uppercase keys (A-Z0-9_) and scalar values; ignore nested objects/lists.

Security:
- Default behavior logs keys only; values are printed only when `HZ_DEBUG=1`.
- In `HZ_DRY_RUN!=0`, inventory loader prints what would be loaded and does not export.

Scope:
- lib/inventory.sh (new)
- bin/hz (add --host flag parsing)
- lib/recipe_loader.sh (load inventory before contract checks)

Links:
- Task: T-006 Inventory Integration

## 2026-02-15 — D-007: Logging Standard

Decision:
- Standardize logging via `lib/logging.sh` with levels: ERROR/WARN/INFO/DEBUG.
- `LOG_LEVEL` controls verbosity (default INFO). `ERROR` logs must go to stderr.
- `bin/hz` parses global flags anywhere in argv:
  - `-v/--verbose` => LOG_LEVEL=DEBUG and HZ_DEBUG=1
  - `-q/--quiet`   => LOG_LEVEL=ERROR
- Default INFO logs must not print secret values. DEBUG logs may print masked values (via hz_mask_kv_line).

Rationale:
- Make failures obvious (stderr) and debugging discoverable without noisy defaults.
- Keep secrets safe by default.

Scope:
- lib/logging.sh
- bin/hz
- lib/cli_core.sh
- lib/inventory.sh
- lib/recipe_loader.sh

Links:
- Task: T-007 Unified Logging & Verbosity
