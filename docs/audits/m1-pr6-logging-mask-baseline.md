# Milestone 1 PR6 Audit Record

## Motivation
- Provide a reusable masking helper and minimum log directory policy baseline.

## Changes
- Added `lib/logging.sh`:
  - `hz_default_log_dir`
  - `hz_prepare_log_dir`
  - `hz_mask_value`
  - `hz_mask_kv_line`
- Added `docs/LOGGING-POLICY.md` with policy and usage guidance.

## Impact Scope
- Shared utility and documentation only.
- No deployment behavior and no remote execution behavior.

## Evidence
- `hz_mask_kv_line` masks configured key patterns.
- Log path strategy defaults to `logs/` and supports override via `HZ_LOG_DIR`.

## Acceptance Commands
- `make check`
- `bash tools/check/vendor_neutral_gate.sh`
- strict secret-risk pattern scan over tracked files

## Rollback
- `git revert <commit>`
