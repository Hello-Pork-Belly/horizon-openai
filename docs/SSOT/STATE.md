# Project State Ledger (SSOT)

This file is the single source of truth for project progress.
Update this file via PR whenever work starts/finishes.

Last updated: 2026-02-18
Owner: Pork-Belly

## Phase Position
- Current Phase: Phase 3 (Fleet Orchestration)
- Phase reference: `docs/SSOT/PHASES.md`
- Progress rule: all status claims must match `PHASES.md` + this file.

## Done (merged tasks)
- (2026-02-13) SSOT bootstrap
- (2026-02-15) T-004 CLI Skeleton (hz) (PR: #63)
- (2026-02-15) T-005 Recipe Runner (hz install) (PR: #64)
- (2026-02-15) T-006 Inventory Integration (PR: #65)
- (2026-02-15) T-007 Unified Logging & Verbosity (PR: #66)
- (2026-02-15) T-008 Port security-host Recipe (PR: #67)
- (2026-02-15) T-009 Port ols-wp Stack (PR: #68)
- (2026-02-15) T-010 Port ols-wp-maintenance Recipe (PR: #69)
- (2026-02-15) T-011 Port Lite Stacks (PR: #70)
- (2026-02-15) T-012 Port hub-data Recipe (PR: #71)
- (2026-02-15) T-013 Port hub-main Recipe (PR: #72)
- (2026-02-15) T-014 Port mail-gateway Recipe (PR: #73)
- (2026-02-15) T-015 Port backup-rclone Recipe (PR: #74)
- (2026-02-15) T-016 Diagnostics & Baseline Engine (PR: #75)
- (2026-02-15) T-017 System Unification & Release v0.2.0 (PR: #76)
- (2026-02-16) T-018 Phase 2 Detailed Plan (Remote Horizon) (PR: #78)
- (2026-02-16) T-019 SSH Transport Layer (PR: #79)
- (2026-02-16) T-020 Remote Inventory & Target Selection (PR: #80)
- (2026-02-16) T-021 Session Recording (Run Records) (PR: #81)
- (2026-02-17) T-022 Remote Runner Implementation (PR: #82)
- (2026-02-17) T-023 Phase 2 Closure & Release v0.3.0 (PR: #83)
- (2026-02-17) T-024 Phase 3 Detailed Plan (Fleet Orchestration) (PR: #85)
- (2026-02-17) T-025 Group Inventory System (PR: #86)
- (2026-02-17) T-026 Parallel Orchestrator (PR: #87)
- (2026-02-17) T-027 Rolling Updates (PR: #88)
- (2026-02-18) T-028 Aggregated Reporting Engine (PR: #91)

## Doing
Parallel rule: only one active task unless Commander explicitly documents an approved parallel exception with risk split.
- (2026-02-18) T-029 UX Hardening (timeouts, interrupt handling, partial report on Ctrl-C) (PR: #<TBD>)

## Next (Phase 3 aligned roadmap)
- T-029 UX Hardening (timeouts, interrupt handling, partial report on Ctrl-C)
- T-030 Phase 3 Closure Gate (DoD consolidation + workflow hygiene closure)
- T-031 Fleet Reporting Schema Freeze (stabilize report.jsonl/report.txt fields and compatibility notes)
- T-032 Fleet Failure Taxonomy (standardize noise_classification and failure buckets in orchestration outputs)
- T-033 Fleet Operator Runbook (group/parallel/rolling/report troubleshooting and acceptance checklist)
