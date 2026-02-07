# Milestone 1 Hygiene Scan

## Scope
- Read-only repository scan before cleanup.
- Goal: identify low-risk deletion candidates with evidence.

## Commands Used
- `find . -maxdepth 3 -type d | sort`
- `for f in docs/acceptance/auto-merge-acceptance.md docs/acceptance/setup-ols-native.md scripts/runner/rebind_repo_runner.sh docs/CONTRIBUTING.md; do ... refs=...; done`
- `for w in .github/workflows/*.yml; do grep -nE 'scripts/|make ' \"$w\"; done`

## Findings
1. Candidate: `docs/acceptance/auto-merge-acceptance.md`
- Evidence: repository reference count is `0`.
- Risk: low (documentation-only, no workflow/Makefile entrypoint reference).

2. Candidate: `docs/acceptance/setup-ols-native.md`
- Evidence: repository reference count is `0`.
- Risk: low (documentation-only, no workflow/Makefile entrypoint reference).

3. Not selected in Milestone 1: `scripts/runner/rebind_repo_runner.sh`
- Evidence: repository reference count is `0`.
- Reason not selected now: script deletion can have out-of-repo operational impact; keep for separate focused PR.

4. Not selected in Milestone 1: `docs/CONTRIBUTING.md`
- Evidence: repository reference count is `0`.
- Reason not selected now: governance doc, keep to avoid process churn.

## Workflow/Entrypoint Cross-Check
- `.github/workflows/ci.yml` runs `make check`.
- No workflow references `docs/acceptance/auto-merge-acceptance.md`.
- No workflow references `docs/acceptance/setup-ols-native.md`.
- Makefile entrypoints are unchanged by this scan.

## Deletion Set Approved For This PR
- `docs/acceptance/auto-merge-acceptance.md`
- `docs/acceptance/setup-ols-native.md`
