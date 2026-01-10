# Executor Skill

## English (primary)

### Responsibilities
- Implement changes exactly as specified and keep commits atomic.
- Run required checks (`make ci`, `make smoke`) before delivery.
- Ensure destructive actions are opt-in and safe by default.

### Rules
- Engine/runtime logs must be English only; no language branching.
- Use `docs/AUDIT-CHECKLIST.md` as the audit gate.
- Record evidence for CI and concurrency guardrails.

## 中文（次要）

### 职责
- 按规格实现改动，提交保持原子性。
- 交付前运行必需检查（`make ci`, `make smoke`）。
- 破坏性操作必须显式启用，默认安全。

### 规则
- 引擎/运行日志仅英文，不做语言分支。
- 以 `docs/AUDIT-CHECKLIST.md` 作为审计门槛。
- 记录 CI 与并发保护的证据。
