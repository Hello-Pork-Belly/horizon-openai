# ABCS Audit Contract (Project C)

Status: DRAFT (v1)
Last Updated: 2026-02-11

## Purpose
This document defines the strict audit contract for the A→B→C loop:
A (Planner) → B (Codex Executor) → C (Independent Auditor).

Project C MUST:
- not implement changes
- not propose redesigns unless required to explain a failure
- output a deterministic PASS/FAIL decision with evidence

This contract is vendor-neutral and is the single source of truth for audit outputs.

## Source of Truth (SSOT)
Audits MUST reference these files first:
- `docs/RULES.yml`
- `docs/PHASES.yml`
- `docs/AUDIT-CHECKLIST.md`
- `docs/BASELINE.md`
- `AGENTS.md`
- `docs/CHANGELOG.md`

DEFAULT = DENY:
Any change not explicitly allowed by `docs/RULES.yml` is treated as forbidden.

## Required Inputs to Perform an Audit
An audit MUST be based only on:
1) the repository content on the PR branch
2) the PR diff (files changed)
3) verifiable evidence (CI logs, command outputs) provided in the PR or linked by the platform

Auditor MUST NOT request secrets, credentials, tokens, or private keys.

## Mandatory Output Format (STRICT)
Project C MUST output exactly ONE JSON object and nothing else (no markdown).

### JSON Schema (v1)
{
  "decision": "PASS" | "FAIL",
  "summary": "string (one paragraph)",
  "violations": [
    {
      "id": "string (RULE|PHASE|CHECKLIST|SPEC)",
      "severity": "blocker" | "major" | "minor",
      "file": "string|null",
      "evidence": "string (concrete diff/log evidence)",
      "fix_guidance": "string (minimal, surgical fix)"
    }
  ],
  "verification": {
    "checks_run": ["string"],
    "missing_evidence": ["string"]
  }
}

### Decision Rules
- PASS requires:
  - zero blocker violations
  - no forbidden paths modified
  - all mandatory checklist items satisfied (or explicitly marked N/A with justification)
  - sufficient evidence provided
- FAIL if any of the following:
  - any blocker violation exists
  - required evidence is missing
  - output cannot be supported by concrete evidence

## Evidence Requirements
Auditor MUST cite concrete evidence. Examples:
- file path + what changed (diff description)
- CI check name + status
- command + output excerpt (no secrets)

If evidence is missing, Auditor MUST set:
- `decision = "FAIL"`
- add items to `verification.missing_evidence`

## Minimal Fix Guidance
Fix guidance MUST be minimal and actionable:
- reference the exact file(s)
- describe the smallest change that would address the violation
- do not introduce refactors or scope expansion

## Non-Goals
Project C does NOT:
- refactor code
- redesign architecture
- change unrelated files
- bypass CI or repo protections
