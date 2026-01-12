# 1-click → HLab Migration Plan

## Goal
Safely copy the most useful, proven components from 1-click into HLab while preserving HLab's rules (UI/engine separation, idempotency, and verification) and keeping scope strictly documentation-only for this plan.

## What to Copy (Component List)
- **Provisioning logic**: node/bootstrap setup, package install ordering, and baseline hardening steps.
- **LOMP-Lite engine pieces**: installation flow, config templates, and verification steps.
- **Security/hardening modules**: firewall rules, SSH hardening, and secret handling patterns.
- **Runner/automation helpers**: reusable run/verify helpers and logging conventions.
- **Validation checks**: health checks, service status checks, and post-install verification steps.

## Target Folder Mapping in HLab
- **UI prompts/menus** → `skills/` (planner/executor/auditor prompts and tasking)
- **Engine scripts** → `scripts/`
- **Verification steps** → `scripts/` (as `verify` modes or explicit verify blocks)
- **Templates/configs** → `docs/` (documented first), then `scripts/` where applicable
- **Operational runbooks** → `docs/`

## Phased Plan

### Phase 1: Inventory & Parity Mapping
**Objective:** Establish a clear mapping of 1-click components to HLab targets.

**Acceptance Criteria:**
- A component inventory list is created with owners and current status.
- Each component is mapped to a target location in HLab (UI vs engine).
- Gaps are documented (missing engine logic, missing verification, missing UI).

### Phase 2: Engine-first Porting
**Objective:** Port high-value engine components with verification.

**Acceptance Criteria:**
- Engine scripts are ported with idempotent behavior and English-only logs.
- Verification modes or explicit verify blocks are implemented for each component.
- No UI language branching appears in engine scripts.

### Phase 3: UI & Workflow Integration
**Objective:** Wire UI prompts/menus to the new engine capabilities.

**Acceptance Criteria:**
- UI prompts/menus call the new engine scripts without embedding logic.
- Documentation updated for new flows and usage.
- `make ci` passes and required smoke coverage exists for the migrated paths.
