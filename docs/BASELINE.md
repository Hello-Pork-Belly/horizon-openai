# Horizon Lab: Engineering Baseline & Standards

> **Status**: Active
> **Enforcement**: Strict
> **Applies to**: All scripts, workflows, and infrastructure code.

---

## 1. Operational Guarantees
Every automation script in this repository must adhere to the following operational principles:

### 1.1 Idempotency (State-Awareness)
* **Rule**: Scripts must be safe to run multiple times without causing side effects or errors.
* **Implementation**:
    * Check if a resource exists before creating it.
    * Check if a configuration line exists before appending it.
    * **Bad**: `mkdir /opt/hlab` (Fails if exists)
    * **Good**: `mkdir -p /opt/hlab` (Succeeds if exists)

### 1.2 Verification (Trust but Verify)
* **Rule**: Every change must include a verification step to confirm success.
* **Implementation**:
    * After installing a package, check `command -v`.
    * After changing config, run syntax check (e.g., `nginx -t`).
    * After restarting service, check status (`systemctl is-active`).

### 1.3 No Interactive Prompts
* **Rule**: Scripts must run fully non-interactively (`DEBIAN_FRONTEND=noninteractive`).
* **Implementation**: Never use `read -p` for user input. All parameters must be passed via Environment Variables or Flags.

---

## 2. Platform & Compatibility

### 2.1 Target OS
* **Primary**: Ubuntu 24.04 LTS (Noble Numbat)
* **Secondary**: Ubuntu 22.04 LTS (Jammy Jellyfish)
* **Constraint**: Do not use features specific to non-LTS releases.

### 2.2 User Context
* **Root Requirement**: Most provisioning scripts require root.
* **Check**: Scripts should include a check for `EUID -eq 0` or use `sudo` explicitly for privileged commands.

---

## 3. Scripting Standards (Strict Enforcement)
To ensure portability across the n8n factory pipeline and execution environments, strictly adhere to these "Pure Bash" rules:

### 3.1 Language & Interpreter
* **Shebang**: MUST use `#!/bin/bash`.
* **Pure Bash**: DO NOT use inline Python (`python -c`), Perl, or Node.js blocks. Logic must be native Bash.
* **JSON Handling**:
    * **Creation**: Use `printf` or `cat` with proper escaping.
    * **Parsing**: `jq` is allowed ONLY IF checked via `check_requirements`.

### 3.2 Tooling & Dependencies
* **Allowed Coreutils**: `sed`, `awk`, `grep`, `cut`, `find`, `sort`, `head`, `wc`, `stat`, `sha256sum`, `curl`, `git`, `tar`, `gzip`.
* **Prohibited**: `yq`, `csvtool`, or non-standard binaries not present in Ubuntu LTS minimal.
* **Dependency Check**: Every script MUST include a `check_requirements()` function at the top to validate tool existence.

### 3.3 Safety & Execution Modes
* **Dry Run Default**: Scripts SHOULD default to `DRY_RUN=1` (read-only / plan mode) where applicable.
* **Safety Flags**: All scripts must start with:
  ```bash
  set -euo pipefail
4. Observability & Logging
4.1 Language
Rule: All log output (Info, Warn, Error) MUST be in English.

Reasoning: To ensure AI Auditors and international maintainers can parse logs deterministically.

4.2 Format
Standard: Use structured prefixes for easy parsing.

[INFO] ...

[WARN] ...

[ERROR] ...

[OK] ... / [FAIL] ...

5. Security Protocols
5.1 Secret Management
Rule: NEVER hardcode secrets (API Keys, Passwords) in scripts.

Method: Use Environment Variables (e.g., ${DB_PASSWORD:?}).

5.2 Network & Firewalls
Rule: When opening ports, default to "Deny All" strategies. Only allow specific IPs/Subnets if possible.
