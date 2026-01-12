# Auto-merge workflow acceptance (Codex PRs)

## Checklist (GitHub UI steps)
1) Create a PR from a branch named `codex/acceptance-auto-merge-e2e`.
2) Ensure the PR is **not** a draft.
3) Add the label `codex`.
4) Verify **Actions** shows **Auto-merge Codex PRs** run (skipped on open is OK), then a successful run after labeling.
5) Verify the PR shows “Auto-merge enabled” (or equivalent) and merges as **squash** when checks pass.
6) Verify the branch is deleted (if configured) or note if not configured.

## Pass/Fail criteria
- **Pass**: All checklist steps complete, auto-merge enables, and the PR merges as squash after checks pass.
- **Fail**: Any checklist step cannot be completed or auto-merge does not enable/merge as expected.

## Troubleshooting
- **gh auth / permissions**: Re-authenticate with `gh auth login` and confirm repository write access.
- **Missing label**: Add the `codex` label and re-check Actions for the auto-merge workflow run.
- **Branch name not starting with `codex/`**: Rename the branch to start with `codex/` and re-open or update the PR.
