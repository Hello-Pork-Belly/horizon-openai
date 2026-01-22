# Codex Skills (HLab)

## Purpose
This directory is the canonical source for HLab Codex auto-discovery skills.
Do not edit `skills/*/SKILL.md` directly; treat this directory as the SSOT.

## Skills
- **hlab-planner**: Turns ambiguous requests into atomic specs and interfaces.
- **hlab-executor**: Implements approved specs with idempotent, defensive bash.
- **hlab-auditor**: Validates changes against architecture, security, and quality rules.

## Canonical Source and Sync Strategy
- Canonical source lives under `.codex/skills/hlab-*/SKILL.md`.
- The `skills/*/SKILL.md` paths are symlinks to the canonical files to enforce SSOT in this repo.
- If symlinks are not supported in a target environment, replace the symlink with a copy
  and add a prominent WARNING line stating it mirrors the canonical file and must not diverge.
  Example warning line for copies:
  `WARNING: This file mirrors .codex/skills/<skill>/SKILL.md and must remain identical.`
