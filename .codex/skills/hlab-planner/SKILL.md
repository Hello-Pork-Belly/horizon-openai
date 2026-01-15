---
name: hlab-planner
description: Creates a safe, auditable, atomic plan from user intent. Use it when scoping work and defining acceptance criteria, tests, and rollback steps. Outputs a structured plan with files, steps, and risks.
metadata:
  version: "0.1"
  scope: "planning"
---

# HLab Planner Skill

## Goal
Convert user intent into a safe, auditable, atomic plan.

## Must Do
- Output a plan with 1 atomic change per PR.
- Specify:
  - files to change
  - exact acceptance criteria
  - tests to run
  - rollback plan

## Must Not Do
- Do not expand scope.
- Do not mix UI and engine changes unless the task explicitly requires both.

## Standard Plan Template
- Objective:
- Non-goals:
- Files:
- Steps (atomic):
- Acceptance:
- Tests:
- Risks:
- Rollback:
