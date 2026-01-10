# Audit Checklist

## English (primary)

### Required checks (must pass)
1. **CI green**
   - `make ci` passes.
   - `make smoke` passes (non-destructive).
2. **No placeholders**
   - No literal three-dot placeholders remain in active workflows, scripts, or README.
3. **Language policy**
   - Docs are English-first; Chinese translations are secondary.
   - Engine/runtime logs are English only; no language branching inside engines.
4. **Concurrency guardrails (OLS + LSPHP/LSAPI)**
   - Limits are set by RAM tier per `docs/BASELINE.md`.
   - **Verify output is captured** in audit evidence (grep/config output).
5. **HLab auto-merge policy**
   - Auto-merge only allowed when CI is green **and** Gemini Auditor issues PASS.
   - PASS must be machine-readable via **Approve** review or `audit-pass` label.

### Evidence to collect
- `make ci` output.
- `make smoke` output.
- OLS and LSAPI config extracts showing concurrency limits.
- Confirmation that no three-dot placeholder remains in active files.

### PASS/FAIL decision
- **PASS** only if all required checks pass and evidence is present.
- **FAIL** if any required check fails or evidence is missing.

**Machine-readable PASS requirement:**
- Provide an **Approve** review **OR** add the `audit-pass` label.

## 中文（次要）

### 必须通过的检查
1. **CI 通过**
   - `make ci` 通过。
   - `make smoke` 通过（非破坏性）。
2. **无占位符**
   - 活跃工作流、脚本、README 中不应存在三点占位符。
3. **语言策略**
   - 文档英文优先，中文为次要。
   - 引擎/运行日志仅英文，禁止语言分支。
4. **并发保护（OLS + LSPHP/LSAPI）**
   - 按内存档设置限制，符合 `docs/BASELINE.md`。
   - **必须记录验证输出** 作为审计证据。
5. **HLab 自动合并策略**
   - 仅当 CI 通过且 Gemini 审计 PASS 时允许自动合并。
   - PASS 必须机器可读：**Approve** 评审或 `audit-pass` 标签。

### 需收集的证据
- `make ci` 输出。
- `make smoke` 输出。
- OLS 与 LSAPI 配置片段，证明并发限制。
- 确认无三点占位符。

### PASS/FAIL 判定
- 只有在所有检查通过且证据齐全时可判定 **PASS**。
- 任一检查失败或缺少证据即 **FAIL**。

**机器可读 PASS 要求：**
- 提交 **Approve** 评审或添加 `audit-pass` 标签。
