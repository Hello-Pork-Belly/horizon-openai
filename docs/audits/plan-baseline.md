# Baseline Delivery Plan (Milestone 1)

## Goal
- Deliver baseline repository capabilities through serial, single-purpose pull requests.
- Keep all changes repo-only and auditable.

## Current State Snapshot
- Check entrypoint exists: `make check` -> `scripts/check/run.sh`.
- CI entrypoint exists: `.github/workflows/ci.yml` runs `make check`.
- `bin/` and `inventory/` do not exist yet.
- `LICENSE` and `VERSION` do not exist yet.

## Planned PR Sequence

### PR-01: Plan Only
- Scope:
  - Add this planning document only.
- Acceptance:
  - `make check` passes.
  - Blocking scans pass (neutral wording and secret-risk scan).
- Rollback:
  - `git revert <commit>`

### PR-02: Repository Metadata Baseline
- Scope:
  - Add `LICENSE`.
  - Add `VERSION`.
  - Update `docs/CHANGELOG.md` with baseline metadata entry.
  - Update `docs/BASELINE.md` with metadata expectations.
- Acceptance:
  - `make check` passes.
  - `VERSION` value is documented and discoverable.
- Rollback:
  - `git revert <commit>`

### PR-03: Minimal CLI + Command Namespace Skeleton
- Scope:
  - Add `bin/hz` minimal CLI with `--version`, `module`, `recipe`, `menu` command stubs.
  - Add directory skeletons: `modules/` and `recipes/` with placeholder docs.
  - Add subcommand contract placeholder: `install/status/check/upgrade/backup/restore/uninstall/diagnostics`.
- Acceptance:
  - `make check` passes.
  - `bin/hz --version` prints project version.
  - `bin/hz module <name> check` and `bin/hz recipe <name> check` parse correctly (placeholder behavior allowed).
- Rollback:
  - `git revert <commit>`

### PR-04: Inventory Schema and Static Validation
- Scope:
  - Add `inventory/hosts/` and `inventory/sites/` structure with non-sensitive examples.
  - Add validator script for YAML parse, required fields, and host/site reference resolution.
  - Add validator docs in `docs/`.
- Acceptance:
  - `make check` passes.
  - Inventory validator returns non-zero on invalid references and zero on valid examples.
- Rollback:
  - `git revert <commit>`

### PR-05: Check Gate Expansion (Static Baseline)
- Scope:
  - Extend `scripts/check/run.sh` to include:
    - shell syntax checks
    - shellcheck checks
    - inventory validator
    - optional formatter check (non-enforcing if absent)
  - Keep CI calling only `make check`.
- Acceptance:
  - `make check` passes locally.
  - CI `ci` job passes with the same entrypoint.
- Rollback:
  - `git revert <commit>`

### PR-06: Logging + Masking Baseline
- Scope:
  - Add shared masking helper for `_PASS`, `_TOKEN*`, `_KEY`, `_SECRET` patterns.
  - Add minimum log path policy (`logs/` default, overridable by env).
  - Add docs for masking behavior and log policy.
- Acceptance:
  - `make check` passes.
  - Unit-style script checks demonstrate masking output without exposing sensitive values.
- Rollback:
  - `git revert <commit>`

## Global Rules for Every PR
- One PR, one functional change.
- No direct push to `main`.
- Local `make check` must pass before push.
- Blocking scans must pass before push:
  - neutral wording scan
  - secret-risk scan
- Add or update a `docs/audits/` record with:
  - motivation
  - evidence
  - impact scope
  - acceptance commands
  - rollback command
