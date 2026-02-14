# Decisions Log (SSOT)

Record any decision that changes behavior, contract, security, or workflow.
Format: date + decision + rationale + scope + links.

## 2026-02-13 — SSOT bootstrap
Decision:
- Establish SSOT files: STATE.md / DECISIONS.md / SPEC-TEMPLATE.md
Rationale:
- Prevent context drift in a medium-sized project.
Scope:
- Repository-wide process
Links:
- PR #<n>, Issue #<n>

## 2026-02-15 — D-001 Auto-merge Strategy
Decision:
- Add a GitHub Actions workflow that enables GitHub Auto-merge only when a PR is labeled `automerge`.
- Implementation uses `gh pr merge --auto --squash` to toggle auto-merge; it does not force-merge or bypass checks.
- Enforce gatekeeping in workflow: allow only actors with repo permission `write|maintain|admin` to trigger enablement.

Rationale:
- Reduce manual toil (“Enable auto-merge” click) while keeping strict quality gates: Branch Protection + required checks still decide when/if merge happens.
- Use `pull_request_target` on `labeled` to obtain write permissions safely without checking out or executing untrusted PR code.
- Dual gating (sender association + API permission check) reduces risk of unintended enablement.

Scope:
- .github/workflows/auto-merge.yml
- docs/SSOT/DECISIONS.md
- docs/SSOT/STATE.md

Assumptions:
- Repository setting “Allow auto-merge” is enabled.
- Branch Protection requires at least the `ci` check on the target branch.

Risks / Notes:
- SSOT rules currently list `.github/workflows/**` as forbidden and `auto_merge_allowed: false` in RULES.yml; this task is an explicitly approved exception via task allowlist. A follow-up task (T-001b) must reconcile RULES.yml to prevent audit ambiguity.

Rollback:
- Delete `.github/workflows/auto-merge.yml` and revert this decision entry.

Links:
- PR #<n>, Issue #<n>

## Template
### YYYY-MM-DD — <Decision Title>
Decision:
- <bullet>
Rationale:
- <bullet>
Scope:
- <paths/modules affected>
Links:
- PR #<n>, Issue #<n>
