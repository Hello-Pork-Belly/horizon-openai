# AGENTS.md — HLab Execution Contract (for Codex / tools)

Purpose: Make changes to HLab safely, predictably, and auditable.

## Golden Rules
1) **Scope control**: Only change what the task requires. No extra refactors.
2) **Atomic PRs**: One PR = one functional change.
3) **Evidence required**: Follow the SSOT in `docs/GPT-PROJECT-INSTRUCTIONS.md`. For MODE:AUDIT, evidence is PR diff only; commands/logs are optional if actually executed.
4) **UI vs Engine separation**:
   - UI = menus, prompts, language selection.
   - Engine = does real work, takes env/args, outputs English logs only.
   - Engine MUST NOT contain language branching (no LANG/LANG_CODE checks).
5) **No fake tuning**: performance/security “tuning” must be real file edits + verify.
6) **Concurrency guardrails are mandatory**: LOMP must include PHP worker/concurrency limits (OLS + LSPHP/LSAPI) by RAM tier, with a verify output that proves the values are applied.
7) **No `sudo -E`**: pass env explicitly, e.g. `sudo VAR=... bash script.sh`.
8) **Secrets safety**:
   - Never hardcode secrets into repo or logs.
   - Never print secrets.
   - Avoid putting `$`-containing secrets inside double quotes in bash.
9) **Compatibility**: Target Ubuntu 22.04/24.04.

## Required Workflow
- Before coding:
  - Read `docs/BASELINE.md` and `docs/AUDIT-CHECKLIST.md`.
  - Identify the minimal files to change.
- During coding:
  - Prefer small, reversible edits.
  - Keep UI strings in UI layer.
  - Keep engine scripts idempotent.
- After coding:
  - Run `make ci` locally (or the repo’s CI equivalent) when required by the task and feasible.
  - Provide evidence in PR body per the SSOT.
  - Never fabricate executed commands or outputs.

## PR Body Template (must follow)
- Goal:
- Scope (files):
- Commands Run:
- Evidence (outputs / screenshots / artifacts):
- Risk Notes:
- Rollback Plan:

## Canonical Commands
- `make lint` / `make lint-strict`
- `make smoke`
- `make ci`

## What NOT to do
- Do not reorder docs/menus unless explicitly requested.
- Do not change unrelated modules.
- Do not add new dependencies without justification.
