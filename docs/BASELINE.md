# HLab Baseline (FROZEN RULES)

This document defines the non-negotiable baseline for HLab.

## A. Product Boundary
- HLab is an experimental workspace to improve the "1 click" system safely.
- Public entrypoint behavior must remain stable unless explicitly switched.

## B. Language Policy
- **Primary UI language**: English (EN-first). Chinese is secondary.
- Development may contain EN/CN mix in comments or docs.
- **Engine output/logs must be English only** and must not branch by language.

## C. Architecture Rules
1) UI/Engine separation is mandatory.
2) Module menus call engines; engines do not call menus.
3) Engines take env/args only; no interactive prompts inside engines.

## D. Security & Safety
- No secrets in repo.
- Any destructive action must include double confirmation in UI.
- For mail alerts: Each server tier must use its own SMTP key (no sharing).

## E. Operational Guarantees
- Idempotency: Running the same install/repair twice should not break the system.
- Verify step: every major action has a `verify` mode or verification block.
- Logs should be structured: `[INFO]`, `[WARN]`, `[ERROR]`.
- **Concurrency guardrails**: LOMP must enforce PHP worker/concurrency limits (OLS + LSPHP/LSAPI) by RAM tier to prevent OOM; every change must include a `verify` output showing effective values and config paths and reload/restart evidence.

## F. Compatibility
- Ubuntu 22.04/24.04.
- No assumptions about public SSH (Tailscale SSH common).

## G. Current Known Project Status (IMPORTANT)
- Only a small part of LOMP-Lite is implemented.
- The "Security/Hardening" part likely exists in scripts but **is not wired into the main flow**.
- When starting a remediation plan, **must explicitly connect the security/hardening flow and add verification**.

## H. Definition of Done (Phase 1)
Phase 1 is done when:
- LOMP-Lite full chain is complete (including security/hardening wired + verified).
- `make ci` passes.
- Regression checklist updated.
