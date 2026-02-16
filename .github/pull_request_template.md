## Summary
- What does this PR change?

## Linked SPEC
- docs/SSOT/<spec or link> (required)

## Reality Snapshot (required)
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

## Evidence (required)
- `make ci`:
  - [paste output or link to checks]
- Any additional verification commands:
  - [paste outputs]

## Risk Level
- [ ] Low (docs/refactor only)
- [ ] Medium (scripts/modules behavior change)
- [ ] High (firewall, backup/restore, secrets handling, uninstall/cleanup)

## SSOT Updates
- [ ] STATE.md updated (Done/Doing/Next)
- [ ] DECISIONS.md updated (if behavior/contract changed)

## Workflow Hygiene Checks
- [ ] Attached Reality Snapshot
- [ ] No red noise in Actions (incl. `No jobs were run`) OR follow-up task created and linked

## Auditor Notes
- Any expected deviations / waivers (must be justified)
