# horizon-lab

Horizon-Hybrid lab repo for Oracle Cloud Free Tier mixed-architecture nodes (ARM hub + x86 edge),
operated via Tailscale mesh and GitHub Actions self-hosted runners.

## Roles
- **Rules Authority:** You (owner of rules & approvals)
- **Commander:** Gemini (tasking & orchestration)
- **Executor:** Codex (strict execution, atomic commits)
- **Lead DevOps Engineer:** ChatGPT (design/spec/scripts under Rules)

## Core rules (non-negotiable)
1. **Anti-Explosion (Resource Control)**
   - Every systemd service MUST set `MemoryHigh` and `CPUQuota`.
   - Low-spec x86 nodes must cap services to ~200–400MB each (unless explicitly approved).
2. **Network Security**
   - Public ports allowed: **80, 443, 4433 (UDP/TCP)** only.
   - SSH/DB ports MUST accept traffic from **Tailscale interface (tailscale0) only**.
3. **Execution Protocol**
   - Prefer **GitHub Actions (self-hosted runner)** for remote execution.
   - One logical change per commit (atomicity). Default = deny.

## Repository structure (baseline)
- `docs/`               Baseline rules, audit checklists, release policy
- `skills/`             Planner/executor/auditor skill pack
- `scripts/`            Idempotent shell scripts (safe defaults)
- `.github/workflows/`  CI + manual_dispatch ops workflows

## Docs
- [GPT Project Instructions](docs/GPT-PROJECT-INSTRUCTIONS.md)
- [Baseline](docs/BASELINE.md)
- [Audit Checklist](docs/AUDIT-CHECKLIST.md)
- [Release Policy](docs/RELEASE-POLICY.md)
- [LOMP Lite Scope](docs/LOMP-LITE-SCOPE.md)
- [1-click → HLab Migration Plan](docs/migration/oneclick-to-hlab.md)

## Quick start
1. Add your nodes to Tailscale (mesh only; no public SSH).
2. Install/attach GitHub runner to the hub node.
3. Use workflows under `.github/workflows/` to apply changes.

## Local/CI
- `make ci`
- `sudo bash scripts/clean_node.sh --dry-run`

## Security notes
- NEVER commit secrets (tokens, keys, .env).
- Use GitHub Actions secrets + per-node secret separation when applicable.
