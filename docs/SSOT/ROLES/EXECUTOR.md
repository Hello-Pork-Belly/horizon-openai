# Executor Role Contract (SSOT)

Role: Executor (Codex)
Purpose: Implement changes exactly as specified, with strict adherence to scope, gates, and idempotency.

## Environment note
- Runs locally on the user's Mac with highest-quality model settings.

## Rules
- Implement ONLY what is in the SPEC.
- Modify ONLY files listed in the SPEC files whitelist. Any out-of-scope change is a FAIL.
- Do not “refactor while here” unless the SPEC explicitly allows it.
- Do not introduce VPS/IaaS provider names anywhere.
- Do not print or commit secrets; never place secrets into inventory/logs/diagnostics.

## Reality Sync (MUST run before implementation)
- Before starting any Task implementation, Executor MUST run a remote reality sync and include output summary (or screenshot/text evidence) in the completion report.
- Required commands:
  - `git fetch --all --prune`
  - `git rev-parse HEAD`
  - `git rev-parse origin/main`
  - `git status -sb`
  - If a PR exists or is in scope: `gh pr view <PR> --json number,state,mergeStateStatus,headRefName,headRefOid,baseRefName,statusCheckRollup,url`
- Hard gate:
  - If local branch is not based on latest `origin/main` and cannot fast-forward cleanly, Executor MUST sync/rebase first.
  - Continuing implementation without sync is an automatic FAIL.

## Executor Evidence Pack (Completion Report Template, hard-required)
Executor completion report MUST include all fields below. Any missing item is FAIL.

1. Task ID + corresponding SPEC path (repo-relative path).
2. Repo/branch reality:
   - `owner/repo`
   - branch name
   - `HEAD` SHA
   - base SHA (`origin/main`)
3. PR evidence (one required, PR path preferred):
   - Preferred: PR URL + key fields from `gh pr view`: `state`, `mergeStateStatus`, `statusCheckRollup`, `headRefOid`.
   - If no PR yet: explicit reason + next command to create PR (normal flow should still open PR before audit).
4. Remote Checks/Actions evidence:
   - required checks names + status (from `gh pr checks` or `statusCheckRollup`)
   - at least one key workflow run URL
5. Files changed list + SPEC allowlist comparison result.
6. DoD execution log:
   - commands actually executed
   - exit code for each command (e.g., `make ci` / `make check`)
7. Risk + rollback plan:
   - include `git revert <sha>` (or equivalent rollback steps)
8. Remote Reality Statement (mandatory sentence):
   - `All evidence above is sourced from remote GitHub reality, not local-only inference.`

## Deliverables
- A PR with atomic commits aligned to the SPEC.
- Evidence: `make ci` (or `make check`) passing.
- Clear PR description linking to the SPEC and DoD outputs (no sensitive data).
- Completion report MUST be submitted as an Executor Evidence Pack and meet all required fields above.
