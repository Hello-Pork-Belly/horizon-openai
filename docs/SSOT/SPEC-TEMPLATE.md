# SPEC Template (SSOT)

Use this template for every change set (ideally 1 PR = 1 SPEC).
All outputs/logs must be vendor-neutral and default to English.

## 0. Reality Snapshot (required)

```text
repo: <url>
main_head: <short sha + link>
task_id: T-XXX
related_pr: <link>
pr_state: open|merged|closed
required_checks: <check name list + result>
actions_failures: <link list, 若无写 none>
noise_classification: none|no-jobs-run|misconfig|real-failure
decision: PROCEED|BLOCKED
```

Rule:
- Missing or incomplete snapshot => SPEC is invalid and cannot proceed.

## 1. Goal
- What problem is solved?
- What is explicitly out of scope?

## 2. Constraints (must comply)
- Vendor-neutral wording everywhere
- No secrets in git/inventory/logs/diagnostics
- DRY_RUN semantics: 0 execute, 1 print actions, 2 plan-only
- Exit codes: 0 ok; 1 expected fail; 2 exec fail; 3 partial; >3 reserved
- Idempotency: rerun safe; only modify managed blocks
- One PR = one theme (Epic Task allowed only under same theme domain + same files allowlist + same rollback strategy)

## 3. Inputs
Inventory:
- files: `inventory/hosts/*.yml`, `inventory/sites/*.yml`
Env (examples):
- `HZ_ENV`, `HZ_DRY_RUN`, `HZ_LOG_DIR`
- site secrets: `HZ_SITE_<SITE_ID>_DB_PASS`, etc.

## 4. Outputs
- Logs: location + format
- Artifacts: backup/manifest/diagnostics (if any)
- User-visible commands: exact CLI examples

## 5. Files to Change
List exact paths and what changes:
- `path/to/file`: change summary

## 6. Implementation Plan
Step-by-step:
1) ...
2) ...

## 7. Verification (DoD)
Must be copy-paste runnable commands, with PASS/FAIL expectations.
- `make ci`
- `hz ... check`
- Any runtime probe commands (ports, tailscale, service status)
- GitHub-side verification items are mandatory:
  - PR state is `open` during review, then `merged` (or auto-merge enabled and completed under green checks)
  - required checks all green
  - Actions has no red noise (`No jobs were run` included); if exists, link follow-up task
Evidence required:
- paste command output snippets (no secrets)

### 7.1 Epic Task Sub-item DoD Checklist (required when Epic Task)
- [ ] Sub-item A: command(s), evidence link(s), PASS/FAIL
- [ ] Sub-item B: command(s), evidence link(s), PASS/FAIL
- [ ] Sub-item C: command(s), evidence link(s), PASS/FAIL

Rule:
- Any sub-item FAIL => overall DoD FAIL.

## 8. Rollback Plan
- How to revert safely (config snapshots, service restore, etc.)

## 9. Security Review Checklist
- [ ] No vendor names introduced
- [ ] No secret printed or logged
- [ ] DB/Redis not exposed on public interfaces
- [ ] Firewall rules idempotent and auditable
