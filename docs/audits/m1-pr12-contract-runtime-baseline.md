# Milestone 1 PR12 Audit Record

## Motivation
- Establish a uniform module/recipe runtime contract usable by `bin/hz` with deterministic status and dry-run semantics.

## Changes
- Reworked `bin/hz` to support:
  - `module list`
  - `recipe list`
  - contract-aware dispatch for `module <name> <subcommand>` and `recipe <name> <subcommand>`
  - unified return code model (`0/1/2/3`)
  - `HZ_DRY_RUN` validation (`0|1|2`)
  - uniform log prefixes (`[INFO]`, `[WARN]`, `[ERROR]`)
- Added contract stubs:
  - `modules/example/contract.yml`
  - `recipes/example/contract.yml`
- Added runner stubs:
  - `modules/example/run.sh`
  - `recipes/example/run.sh`
- Updated namespace docs:
  - `modules/README.md`
  - `recipes/README.md`

## Impact Scope
- Local command contract only.
- No deployment behavior and no remote host interaction.

## Evidence
- `bash bin/hz module list` enumerates module contracts.
- `bash bin/hz recipe list` enumerates recipe contracts.
- Contract calls run with validated subcommand and dry-run semantics.

## Acceptance Commands
- `make check`
- `bash bin/hz --version`
- `bash bin/hz module list`
- `bash bin/hz module example check`
- `HZ_DRY_RUN=2 bash bin/hz recipe example install`
- `bash scripts/check/vendor_neutral_gate.sh`
- strict secret-risk pattern scan over tracked files

## Rollback
- `git revert <commit>`
