# Milestone 1 PR5 Audit Record

## Motivation
- Expand the unified check gate with inventory schema validation and optional formatter check.

## Changes
- Updated `tools/check/run.sh` to add:
  - inventory validation step (`tools/check/inventory_validate.sh`)
  - optional `shfmt -d` step when `shfmt` is available
- Existing CI entrypoint remains `make check`.

## Impact Scope
- Check pipeline only.
- No deployment behavior, no remote behavior, no interface break for CI entrypoint.

## Evidence
- `make check` passes with expanded steps.
- Inventory validator path is executed when present.
- Optional formatter check remains non-blocking when formatter is absent.

## Acceptance Commands
- `make check`
- `bash tools/check/vendor_neutral_gate.sh`
- strict secret-risk pattern scan over tracked files

## Rollback
- `git revert <commit>`
