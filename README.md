# horizon-openai

Horizon is a `./bin/hz`-first one-click installation and operations toolkit for mixed architecture nodes (ARM hub + x86 edge), validated through non-destructive CI gates.

## Quick Start

1) Check version (must match `VERSION`):
- `./bin/hz --version`

2) List available recipes:
- `./bin/hz recipe list`

3) Dry-run (safe mode used by CI):
- `HZ_DRY_RUN=1 ./bin/hz recipe <recipe_name> install`

4) Real execution (run on target node, usually with root/sudo; never in CI):
- `./bin/hz recipe <recipe_name> install`

## Inventory (configuration injection)

The inventory directory maps YAML values into environment variables used by recipe execution (priority: Global < Host < Shell).

Typical usage:
- `./bin/hz recipe <recipe_name> install` (use current shell environment overrides)
- If your hz version supports host selection (e.g. `--host web01`), pass it per repository convention.

## CI / Local Validation

- `make check`: unified checks via hz (version consistency + shellcheck + all-recipe dry-run install)
- `make ci`: alias used by CI

## Recipes

See `docs/RECIPES.md`.
