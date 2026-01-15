# Codex Skills (HLab)

## Purpose
This directory is the canonical source for HLab Codex auto-discovery skills.

## Skills
- **hlab-planner**: Turns user intent into a safe, auditable, atomic plan.
- **hlab-executor**: Executes approved plans and reports commands, diffs, and test outputs.
- **hlab-auditor**: Audits changes against the checklist and issues PASS/FAIL.

## Canonical Source and Sync Strategy
- Canonical source lives under `.codex/skills/hlab-*/SKILL.md`.
- The `skills/*/SKILL.md` paths are symlinks to the canonical files to enforce SSOT.
- If symlinks are not supported in a target environment, replace the symlink with a copy
  and add a prominent WARNING line stating it mirrors the canonical file and must not diverge.
