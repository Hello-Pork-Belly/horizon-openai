# Audit Checklist (PASS/FAIL)

This checklist is used by the auditor to judge every PR.

## 0) Required Evidence
See docs/GPT-PROJECT-INSTRUCTIONS.md (SSOT). This checklist must not diverge.
Versioning/change-history SSOT is docs/VERSIONING.md.

PR must include:
- Goal summary (1-3 lines)
- List of changed files
- PR diff (reviewable and complete)

Optional (only if actually executed): commands + outputs/logs.
Never fabricate executed commands or outputs.

FAIL if PR diff is missing, unclear, or unreviewable.

## 1) Scope & Atomicity
- ✅ Only requested scope changed
- ✅ One PR = one functional change
FAIL if unrelated refactors or broad rewrites exist.

## 2) UI vs Engine Separation
- ✅ No language branching in engines
- ✅ No interactive prompts in engines
- ✅ UI is the only place with CN/EN texts
FAIL if engine contains UI logic or LANG checks.

## 3) Real Changes (No Fake Logic)
- ✅ If PR claims tuning, must show:
  - file before/after diff, and
  - verification command/output
FAIL if only log messages changed.

### 3.1) PHP Worker / Concurrency Guardrails (LOMP)
- ✅ If the PR targets LOMP stability/performance, it must include **real** concurrency limits:
  - OLS side (connections/instances limits as applicable), and
  - LSPHP/LSAPI side (PHP worker/children/concurrency limits as applicable)
- ✅ Must include `verify` output proving effective values (show key parameters + file paths + reload/restart evidence)
FAIL if it only changes logs, comments, or UI text without enforcing real limits.

## 4) Safety & Secrets
- ✅ No secrets committed
- ✅ No secrets printed in logs
- ✅ Destructive ops require double confirmation (UI)
FAIL if any risk is introduced without mitigation.

## 5) Compatibility
- ✅ Works on Ubuntu 22.04/24.04
- ✅ Avoids `sudo -E`
FAIL if relies on fragile assumptions.

## 6) Tests / CI
- ✅ `make ci` (or equivalent) passes
- ✅ Smoke test covers the changed path
- ✅ Shell static checks cover `scripts/`, `recipes/`, `modules/`, and `upstream/oneclick/` for all `*.sh`.
  - Allowed ShellCheck exceptions for `upstream/oneclick/` only: `SC1091`, `SC2034`, `SC2153`, `SC2154` (upstream constants, external source includes, and upstream dynamic variable indirection).
FAIL if CI is not updated to cover new behavior.

## 7) Documentation
- ✅ Docs updated if behavior changed
- ✅ Paths in docs match repo reality
FAIL if docs are broken.

## 8) Consistency & Integrity (The "A-F" Baseline)
- **A) Docs ↔ Makefile**: Any referenced make target must exist in Makefile.
- **B) Workflow ↔ Repo**: Referenced scripts/paths must exist in the repo.
- **C) Env Consistency**: Workflow env vars must match script usage exactly (names, defaults).
- **D) No Dead Inputs**: Required inputs/args must be utilized by implementation.
- **E) Dependency Reality**: Used tools (e.g., rg, jq) must be explicitly installed/verified.

## Auditor Output Format
- Decision: PASS / FAIL
- Reasons (bullet list)
- Required fixes (if FAIL)
- Evidence referenced (links/log snippets)
