# SSOT Phase Index

This file defines canonical project phases and their gates.
All progress statements such as "we are at Phase X / T-YYY" MUST be validated against this file and `docs/SSOT/STATE.md`.

## Usage Rules (hard)
- Phase truth source: `PHASES.md` + `STATE.md` only.
- Task truth source: `STATE.md` Done/Doing/Next only.
- If conflict exists, open a PR to reconcile SSOT before claiming phase/task progress.

## Phase 1 — Local Foundation & Runnable Baseline
- **Purpose**: Build a stable local execution baseline, SSOT process, and recipe/CLI foundations.
- **Entry Gate**:
  - SSOT files exist and are used as execution source of truth.
- **Exit Gate**:
  - CLI skeleton, recipe runner, inventory integration, and baseline diagnostics are merged and usable locally.
- **Task Range**:
  - `T-001 ~ T-017`

## Phase 2 — Remote Execution Foundation
- **Purpose**: Evolve from local-only execution to reliable single-target remote operations.
- **Entry Gate**:
  - Phase 1 exit gate satisfied.
- **Exit Gate**:
  - Remote transport, target selection, session recording, remote runner, and phase closure merged.
- **Task Range**:
  - `T-018 ~ T-023`

## Phase 3 — Fleet Orchestration
- **Purpose**: Deliver group-based orchestration (parallel/rolling/reporting/hardening) on top of remote execution.
- **Entry Gate**:
  - Phase 2 exit gate satisfied.
- **Exit Gate**:
  - Group inventory, parallel orchestration, rolling strategy, aggregated report artifacts, and UX hardening merged.
- **Task Range**:
  - `T-024 ~ T-029`
- **Current SSOT Status**:
  - In progress (see `STATE.md` Doing/Next for active and pending items).
