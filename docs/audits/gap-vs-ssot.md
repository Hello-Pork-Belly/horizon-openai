# Gap Analysis vs SSOT Baseline

## Scope
- Repository-only baseline delivery status.
- No deployment, no host access, no remote execution workflows.

## Completed
1. Metadata baseline
- `LICENSE` present.
- `VERSION` present.
- `docs/CHANGELOG.md` and `docs/BASELINE.md` updated.

2. CLI and namespace skeleton
- `bin/hz` exists with `--version`, `module`, `recipe`, `menu`.
- `modules/` and `recipes/` skeleton docs exist.
- Subcommand contract list exists (`install/status/check/upgrade/backup/restore/uninstall/diagnostics`).

3. Inventory static baseline
- `inventory/hosts/` and `inventory/sites/` examples exist.
- `tools/check/inventory_validate.sh` exists and runs local static checks.

4. Unified check gate baseline
- `make check` is CI entrypoint.
- `tools/check/run.sh` includes shell syntax, shellcheck (if installed), inventory validation, optional `shfmt`, smoke (conditional), and neutral wording gate.

5. Logging/masking baseline
- `lib/logging.sh` added with log directory and masking helpers.
- `docs/LOGGING-POLICY.md` documents policy.

## Not Completed
1. Module/recipe runtime contract enforcement
- `bin/hz` supports command parsing but does not yet enforce:
  - unified return code contract (`0/1/2/3`)
  - explicit DRY_RUN (`0/1/2`) semantics in command execution
  - standardized log prefix contract in module/recipe execution path

2. Inventory validator strictness and error format
- validator performs key/reference checks but lacks:
  - stricter value constraints (allowed enums, basic field format checks)
  - normalized machine-readable error format

3. Interface consistency gate for modules/recipes
- `make check` does not yet verify module/recipe interface manifests and command support declarations.

## Next PR List
1. PR-A: Module/Recipe contract baseline
- Add module/recipe manifest-based contract stubs.
- Update `bin/hz` to enforce return-code model, DRY_RUN semantics, and uniform log prefix for stub path.

2. PR-B: Inventory validator strict mode
- Add allowed value constraints and normalized error output format for local static validation.

3. PR-C: Interface consistency checks in `make check`
- Add checker to verify each module/recipe manifest declares required subcommands.
- Add this checker to `tools/check/run.sh`.

## Acceptance for Next PRs
- Local: `make check` must pass before push.
- Repository scans:
  - neutral wording gate pass
  - strict secret-risk scan pass
- CI: required `ci` check pass before merge.

## Rollback
- Each PR uses single-commit rollback via `git revert <commit>`.
