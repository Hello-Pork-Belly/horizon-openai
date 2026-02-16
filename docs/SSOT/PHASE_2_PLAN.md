# Phase 2 Plan: Remote Horizon (Agentless Remote Execution)

Owner: Horizon SSOT
Status: Draft (T-018)
Target Release: v0.3.x (first remote MVP), v0.4.x (fleet-grade)

## 1. Goals and Non-Goals

Goals:
- Provide remote execution: `hz run --target <user@host> <recipe> [--host <inventory_host>] [--dry-run]`.
- Agentless operation: targets do NOT require hz pre-installed.
- Deterministic and auditable execution: exact payload content, run-id, and logs are reproducible.
- Keep Phase 1 contracts/inventory semantics: Contract-First, Global < Host < Shell (Controller-side overrides stay highest).
- Secure by default: avoid printing secrets; avoid opening inbound ports; use SSH only.

Non-Goals (Phase 2 MVP):
- No long-running daemon/agent on target.
- No multi-target parallel orchestration in MVP (added later).
- No full configuration management re-implementation (Ansible/Terraform-like features are out of scope).
- No automatic privilege escalation discovery; remote user must already have sudo or be root.

## 2. Architecture Overview

Core concept: The Transient Runner.
- Controller (the machine running hz) assembles a minimal “payload bundle” containing:
  - `bin/hz` (or a dedicated remote shim)
  - `lib/` (cli_core, logging, recipe_loader, inventory)
  - `recipes/<name>/` (run.sh + contract.yml)
  - optionally `tools/` required by that recipe (filtered allowlist)
  - a generated `payload.env` (inventory-expanded, masked for logs, not stored after run)
  - a generated `run.json` metadata file (run-id, timestamps, target, recipe, git sha)

Transport & execute:
1) Build bundle locally (tar.gz) in a temp dir.
2) Copy bundle to target via `scp` (or stream via `ssh ... 'tar -xz'`).
3) On target, extract to `/tmp/hz-run-<run-id>/`.
4) Execute runner:
   - `bash /tmp/hz-run-<run-id>/bin/hz recipe <recipe> install` (or direct runner entry)
   - pass env via:
     - `env -i $(cat payload.env) HZ_* ... bash ...` (preferred; avoids leaking into shell profile)
5) Stream stdout/stderr back to Controller (SSH already does this).
6) Collect artifacts:
   - Optionally copy back a log file (if we tee to a file on target).
7) Cleanup:
   - Remove `/tmp/hz-run-<run-id>` on success.
   - On failure: keep directory unless `--cleanup` requested, to aid debugging.

Default transport choice:
- SSH with ControlMaster multiplexing (later). MVP uses plain `ssh` + `scp`.

## 3. Inventory Schema Expansion (Phase 2)

Current Phase 1 inventory is env-var oriented. Phase 2 extends it to include connection assets.

Proposed inventory layout:
- `inventory/group_vars/all.yml` (global defaults, including common ports)
- `inventory/hosts/<name>.yml` (host vars + connection vars)
- Optionally: `inventory/hosts.yml` (host registry) or `inventory/hosts/<name>.yml` only.

Minimum connection keys (per host):
- `HZ_HOST_ADDR` (ip or dns)
- `HZ_HOST_USER` (ssh user)
- `HZ_HOST_PORT` (default 22)
- `HZ_HOST_KEY_PATH` (optional; if empty, use ssh-agent/default key)
- `HZ_HOST_SUDO` (true/false; default true)

Example: `inventory/hosts/web01.yml`
- HZ_HOST_ADDR: "203.0.113.10"
- HZ_HOST_USER: "ubuntu"
- HZ_HOST_KEY_PATH: "~/.ssh/id_ed25519"
- HZ_HOST_SUDO: "true"
- plus recipe vars (e.g., WP_DOMAIN, DB_PASSWORD, etc.)

Selection rules:
- `hz run --host web01 <recipe>` loads:
  1) group_vars/all.yml
  2) hosts/web01.yml
  3) shell env overrides (controller CLI environment)
- `hz run --target user@ip` bypasses host file discovery for connection vars, but still may load group_vars/all.yml for recipe defaults.

## 4. Remote Execution Semantics

Command surface (MVP):
- `hz run --target user@host <recipe>`
- `hz run --host <inv_host> <recipe>` (preferred for fleets)
- flags:
  - `--dry-run` (controller builds payload and runs remote in dry-run mode)
  - `--no-cleanup` (keep /tmp dir on target)
  - `--print-plan` (print resolved inventory keys list, masked)
  - `--timeout <sec>` (ssh command timeout)

Execution environment:
- Use `env -i` to create a clean environment and inject only:
  - Inventory vars for recipe
  - HZ runtime vars (HZ_DRY_RUN, LOG_LEVEL, etc.)
- Always set:
  - `REPO_ROOT=/tmp/hz-run-<id>` (or compute inside)
  - `HZ_REMOTE=1`
  - `HZ_RUN_ID=<id>`

Contract enforcement location:
- Still enforced by the same runner logic (inside the transient payload on target).
- Controller should also pre-validate contract before shipping to reduce unnecessary remote ops:
  - parse contract.yml locally
  - check required env after inventory load
  - abort early if missing (no ssh)

## 5. Payload Packaging Strategy

MVP: “Minimal Copy” packaging.
- Always include:
  - `bin/hz`
  - `lib/` (required libs)
  - `recipes/<recipe>/`
- Include `tools/` only when needed:
  - Strategy A (best default): include full `tools/` in MVP for simplicity; refine later.
  - Strategy B (later optimization): dependency scanning (grep tools paths) + allowlist per recipe.

Chosen for MVP: Strategy A (include `tools/`).
Rationale: fastest path to correctness; payload size acceptable for small repos. Optimize in Phase 2.2.

Bundle format:
- tar.gz
- deterministic file order (sort) to keep hash stable
- compute `payload.sha256` on controller for audit

## 6. Logging and Artifacts

Requirements:
- Controller console output must be readable and consistent with Phase 1 logging.
- Secrets never printed at INFO level.
- Each remote run produces:
  - run-id
  - target
  - recipe
  - duration
  - result code
  - optional artifacts path (logs)

MVP logging approach:
- ssh streams stdout/stderr live to controller.
- optionally tee on controller: `hz run ... | tee logs/<run-id>.log` (controller-side tee avoids secrets on target disk).
- add `--save-log logs/<run-id>.log` later.

Masking:
- reuse existing `hz_mask_kv_line` behavior for debug prints.
- never echo raw password envs.

## 7. Security Model and Risks

Threat model:
- Controller holds secrets (inventory + env overrides). Remote execution must avoid leaving secrets on disk.
- SSH key handling must not weaken security.

Controls (MVP):
- Do not write secrets to remote disk:
  - Avoid writing `payload.env` to remote disk; pass env via SSH heredoc/inline `env` where possible.
  - If we must write, ensure file mode 600 and delete on cleanup.
- Use strict SSH options:
  - `-o BatchMode=yes`
  - `-o StrictHostKeyChecking=accept-new` (MVP) or `yes` (more secure, but may break first connect)
  - `-o IdentitiesOnly=yes` when key path is specified
- Respect branch protection & CI: remote execution is user-invoked, not CI-invoked.

Open decisions (future):
- Host key management policy (known_hosts store).
- Secrets at rest encryption for inventory (SOPS/age integration).

## 8. Task Breakdown (Phase 2 Roadmap)

T-019 SSH Transport Layer (MVP)
- Add `hz run` command:
  - resolves target from `--target` or `--host`
  - pre-validates contract locally
  - packages payload tarball
  - streams tarball to target and executes
  - returns remote exit code
- Add minimal ssh helper lib: `lib/remote_ssh.sh` (later task allowlist)

T-020 Remote Inventory & Target Selection
- Extend inventory loader to parse host connection keys (HZ_HOST_ADDR/USER/PORT/KEY_PATH)
- Add `hz target list` and `hz target show <host>` (optional)

T-021 Remote Logging & Run Records
- Generate run-id and run metadata (json)
- Add controller-side log capture (`--save-log`)
- Add `hz runs list` (local history) (optional)

T-022 Payload Minimization & Dependency Scanning
- Only ship required tools/libs per recipe
- Add per-recipe manifest (optional)

T-023 Hardening
- strict host key policies
- secret handling: no remote env files by default
- timeout/retry policies
- concurrency (multi-target fan-out)

## 9. Acceptance Criteria for Phase 2 MVP (v0.3.x)

- `hz run --target user@host security-host --dry-run` works (no remote changes).
- `hz run --host web01 hub-main --dry-run` works using inventory.
- Contract-first behavior preserved:
  - missing required vars aborts before ssh.
- Remote run does not crash when a service is missing (same ethos as Phase 1).
- No secrets printed in default logs.
