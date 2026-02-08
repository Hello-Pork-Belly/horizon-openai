# Host Security and Alert Contract (Repo-Only)

## Scope
Define local dry-run planning requirements for host hardening and alerting.
All actions are plan-only outputs.

## Hardening Items
- brute-force protection policy for remote access service.
- periodic rootkit scan policy and report schedule.
- log retention caps with rotation targets.

## Alerting Items
- email notification targets and event routing.
- thresholds for CPU, RAM, disk, and service liveness checks.
- periodic summary and failure escalation plan.

## Required Dry-Run Sections
1. `plan.preflight`
2. `plan.bruteforce_guard`
3. `plan.rootkit_scan`
4. `plan.log_retention`
5. `plan.alert_mail`
6. `plan.thresholds`
7. `plan.service_watch`
8. `plan.rollback`
