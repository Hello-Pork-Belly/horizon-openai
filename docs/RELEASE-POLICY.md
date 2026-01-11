# Release Policy (Single Track)

- The public entrypoint remains single-track.
- HLab is used to iterate until the target quality bar is met.
- When switching the public entrypoint target, prefer a tagged release.

## Auto-merge Policy (HLab only)
- Auto-merge is allowed **only in HLab** (not in the stable 1 click repo).
- Auto-merge may proceed **only when**:
  1) Required CI checks are green (e.g. `make ci`, `make smoke`)
  2) Gemini Auditor issues an explicit **PASS** based on `docs/AUDIT-CHECKLIST.md`
- The PASS signal must be machine-readable (choose one):
  - Gemini leaves an **Approve** review on the PR, OR
  - Gemini applies a label: `audit-pass`
- If any check fails or the audit is FAIL, auto-merge must not happen.

## Quality Bar (minimum)
- LOMP-Lite end-to-end (including security/hardening wired)
- `make ci` passes
- Smoke test for the install path
- Audit PASS
- Auto-merge (if enabled) requires CI green + Gemini Audit PASS

## Rollback
- Keep last known-good tag.
- Re-point entry to the last known-good tag if issues appear.
