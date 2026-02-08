# Release Policy (Single Track)

- The public entrypoint remains single-track.
- HLab is used to iterate until the target quality bar is met.
- When switching the public entrypoint target, prefer a tagged release.

## Merge Policy
- PR merge requires explicit manual confirmation by a maintainer.
- Required CI checks must be green before manual merge.
- If any check fails or the audit is FAIL, the PR must not be merged.

## Quality Bar (minimum)
- LOMP-Lite end-to-end (including security/hardening wired)
- `make ci` passes
- Smoke test for the install path
- Audit PASS
- Manual merge requires CI green + Gemini Audit PASS

## Rollback
- Keep last known-good tag.
- Re-point entry to the last known-good tag if issues appear.
