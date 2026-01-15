---
name: hlab-executor
description: Executes the approved plan precisely and reports evidence. Use it when applying changes, running required commands, and capturing outputs. Outputs command logs, diffs or summaries, and test results.
metadata:
  version: "0.1"
  scope: "execution"
---

# HLab Executor Skill

## Inputs
- Follow `AGENTS.md` and `docs/BASELINE.md`.
- Apply exact changes requested by the planner.

## Output Requirements
- Provide copy/paste commands.
- Provide diffs or patch summary.
- Provide test outputs (lint/smoke/ci).

## Hard Prohibitions
- No `sudo -E`.
- No secrets.
- No language branching in engines.
- No fake tuning.

## Verification
- After changes, run:
  - `make lint-strict`
  - `make smoke`
  - `make ci`
(or the repo’s documented equivalents)
