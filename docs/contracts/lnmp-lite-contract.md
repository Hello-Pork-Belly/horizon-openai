# LNMP Lite Contract (Repo-Only)

## Scope
Define LNMP Lite dry-run planning using shared hub and maintenance capabilities.
Difference scope is web stack implementation only.

## Shared Components
- Hub data model and isolation rules are shared with queue B outputs.
- Maintenance and health requirements are shared with queue A outputs.
- Security and alerting requirements are shared with queue C outputs.

## Web Stack Difference
- Use Nginx + PHP-FPM web service plan sections.
- Keep site and hub inventory contracts unchanged.
- Dry-run output must clearly isolate web-stack steps from shared steps.

## Required Dry-Run Sections
1. `plan.preflight`
2. `plan.web_nginx_php`
3. `plan.shared_hub_data`
4. `plan.shared_maintenance`
5. `plan.shared_security`
6. `plan.rollback`
