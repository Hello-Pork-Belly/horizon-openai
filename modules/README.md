# Modules

This directory hosts reusable module implementations.

Expected command contract per module:
- `install`
- `status`
- `check`
- `upgrade`
- `backup`
- `restore`
- `uninstall`
- `diagnostics`

Contract file:
- Path: `modules/<name>/contract.yml`
- Required keys:
  - `name`
  - `runner` (repo-relative script path)
  - `supported_subcommands` (comma-separated list)

Runtime expectations:
- Return codes:
  - `0`: success
  - `1`: expected validation failure
  - `2`: execution failure
  - `3`: partial success
- `HZ_DRY_RUN` semantics:
  - `0`: apply mode
  - `1`: action preview
  - `2`: plan-only mode
