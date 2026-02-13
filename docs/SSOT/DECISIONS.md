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

## 2026-02-13 — Roles + Workflow solidification for SSOT execution
Decision:
- Establish role contracts under docs/SSOT/ROLES/.
- Enforce “Best Default, no ambiguity” as a mandatory Planner behavior.
- Allow auto-merge only when required checks pass and audit is PASS; no manual bypass of gates.
- Keep SSOT precedence and PR-only workflow as non-negotiable governance.
Rationale:
- Reduce execution ambiguity across Commander/Planner/Executor/Auditor handoffs.
- Standardize merge safety and prevent gate circumvention.
Scope:
- docs/SSOT/ROLES/*.md
- docs/SSOT/STATE.md
- docs/SSOT/DECISIONS.md
Links:
- PR: docs(ssot): add role contracts and bootstrap process ledger

## Template
### YYYY-MM-DD — <title>
Decision:
- <bullet>
Rationale:
- <bullet>
Scope:
- <paths/modules affected>
Links:
- PR #<n>, Issue #<n>

## T-001 Auto-merge Enabler (GitHub Actions)
Decision: Use a GitHub Actions workflow to automatically enable GitHub Auto-merge when a PR is labeled `automerge`, by running `gh pr merge --auto --squash`.

Rationale:
- We want to remove manual UI clicks while preserving strict gatekeeping and not bypassing CI.
- `gh pr merge --auto` does not force-merge; it only enables auto-merge. The actual merge still requires repository branch protection / required status checks.

Implementation choices:
- Trigger: `pull_request_target` on `types: [labeled]`.
  - This provides the required permissions to update PR merge settings while avoiding executing untrusted PR code.
  - The workflow performs API operations only and does NOT checkout or run PR code.
- Gatekeeping: hard-check `github.event.sender.association` is one of `OWNER|MEMBER|COLLABORATOR` before enabling auto-merge.
- Permissions: minimal `pull-requests: write`, `contents: read`, using `secrets.GITHUB_TOKEN`.

Assumptions:
- Repository branch protection rules and required status checks are configured so auto-merge cannot bypass CI.

备注（重要但不阻塞）：如果仓库当前未在 GitHub 仓库设置里启用 “Allow auto-merge”，即使 workflow 运行成功也可能无法启用 auto-merge；这种情况需要在仓库 Settings 里开启该功能（属于仓库配置前提，不需要改代码）。
