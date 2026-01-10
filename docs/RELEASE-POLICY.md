# Release Policy

## English (primary)

### Goals
- Keep releases safe, auditable, and reversible.
- Ensure HLab auto-merge is gated by CI and auditor PASS.

### Auto-merge requirements (HLab)
Auto-merge is allowed **only** when:
1) Required CI checks are green (`make ci`, `make smoke`).
2) Gemini Auditor issues an explicit PASS based on `docs/AUDIT-CHECKLIST.md`.
   PASS must be machine-readable via either an **Approve** review or the `audit-pass` label.

### Release steps
1. Ensure baseline requirements are met (`docs/BASELINE.md`).
2. Run `make ci` and confirm `make smoke` is non-destructive.
3. Collect audit evidence per `docs/AUDIT-CHECKLIST.md`.
4. Merge only after CI green and auditor PASS.

### Rollback policy
- Prefer revert commits or tagged rollback branches.
- Document rollback steps in the PR if risk is non-trivial.

## 中文（次要）

### 目标
- 发布过程安全、可审计、可回滚。
- HLab 自动合并必须受 CI 与审计 PASS 约束。

### 自动合并要求（HLab）
仅当满足以下条件时允许自动合并：
1) 必要 CI 通过（`make ci`, `make smoke`）。
2) Gemini 审计员依据 `docs/AUDIT-CHECKLIST.md` 明确 PASS。
   PASS 必须机器可读：**Approve** 评审或 `audit-pass` 标签。

### 发布步骤
1. 确认满足基线要求（`docs/BASELINE.md`）。
2. 运行 `make ci` 并确认 `make smoke` 非破坏。
3. 按 `docs/AUDIT-CHECKLIST.md` 收集审计证据。
4. 仅在 CI 通过且审计 PASS 后合并。

### 回滚策略
- 优先使用 revert 提交或回滚分支。
- 如有明显风险，需在 PR 中记录回滚步骤。
