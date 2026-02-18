# SSOT Phase Index (Deprecated mirror)

> ⚠️ **Deprecated as a truth source**: `docs/PHASES.yml` is the **only** phase truth source in this repository.
> This markdown file is a human-readable mirror/guide only and must not be cited as authoritative phase truth.
> Sync rule: when conflicts exist, update `docs/PHASES.yml` first, then optionally refresh this file to match.

This file provides a readable overview of phases and task ranges. For any gate/closure/progress claim, use `docs/PHASES.yml` + `docs/SSOT/STATE.md`.

## Usage Rules (hard)
- Phase truth source: `docs/PHASES.yml` (authoritative) + `docs/SSOT/STATE.md` (execution state).
- Task truth source: `docs/SSOT/STATE.md` Done/Doing/Next only.
- If conflict exists, open a PR to reconcile SSOT before claiming phase/task progress.

## Mirror overview
- Phase 1 — Local Foundation & Runnable Baseline (`T-001 ~ T-017`)
- Phase 2 — Remote Execution Foundation (`T-018 ~ T-023`)
- Phase 3 — Fleet Orchestration (`T-024 ~ T-029`)
- Phase 4 — Autonomous Horizon (`T-030 ~ T-035`)
- Phase 5 — Operations & Interface (`T-036 ~ T-040`)
