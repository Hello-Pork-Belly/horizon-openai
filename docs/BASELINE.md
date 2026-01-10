# HLab Baseline (Runnable)

## English (primary)

### Purpose
This baseline defines the minimum rules and guardrails required to operate Horizon-Lab safely and repeatably.

### Language policy
- Documentation is English-first; Chinese is secondary.
- Engine/runtime logs must be English only.
- Do **not** add language branching inside engines or scripts.

### Execution safety
- Default to dry-run for destructive scripts.
- All destructive operations must be explicitly enabled (e.g., `APPLY=true`).
- Remote execution is preferred through GitHub Actions self-hosted runners.

### Concurrency guardrails (mandatory)
OpenLiteSpeed (OLS) + LSPHP/LSAPI limits **must** be set by RAM tier. Both the web server limits and PHP worker limits are required.

| RAM tier | OLS `MaxConn` | OLS `MaxSSLConn` | PHP `PHP_LSAPI_CHILDREN` | LSAPI External App `Max Connections` |
| --- | --- | --- | --- | --- |
| ≤2 GB | 200 | 50 | 4 | 4 |
| 3–4 GB | 400 | 100 | 8 | 8 |
| 5–8 GB | 800 | 200 | 12 | 12 |
| >8 GB | 1200 | 300 | 16 | 16 |

**Verify output requirement:** capture and record the configuration output for audits, including:
- OLS server tuning values (e.g., `grep -n "MaxConn" -n /usr/local/lsws/conf/httpd_config.conf`).
- LSAPI external app limits (e.g., `grep -n "maxConns" -n /usr/local/lsws/conf/httpd_config.conf`).
- PHP worker environment (e.g., `grep -n "PHP_LSAPI_CHILDREN" -n /usr/local/lsws/conf/*`).

### Auto-merge policy (HLab)
Auto-merge is allowed only when:
1) Required CI checks are green (`make ci`, `make smoke`), and
2) Gemini Auditor provides an explicit PASS based on `docs/AUDIT-CHECKLIST.md`.
   PASS must be machine-readable via either an **Approve** review or the `audit-pass` label.

## 中文（次要）

### 目的
本基线定义了 Horizon-Lab 可运行的最低规则与保护措施。

### 语言策略
- 文档以英文为主；中文为次要补充。
- 引擎/运行日志必须仅使用英文。
- 不允许在引擎或脚本中做语言分支。

### 执行安全
- 破坏性脚本默认 dry-run。
- 破坏性操作必须显式启用（例如 `APPLY=true`）。
- 远程执行优先使用 GitHub Actions 自托管 Runner。

### 并发保护（强制）
必须按内存分档设置 OLS 与 LSPHP/LSAPI 的并发限制。

| 内存档 | OLS `MaxConn` | OLS `MaxSSLConn` | PHP `PHP_LSAPI_CHILDREN` | LSAPI 外部应用 `Max Connections` |
| --- | --- | --- | --- | --- |
| ≤2 GB | 200 | 50 | 4 | 4 |
| 3–4 GB | 400 | 100 | 8 | 8 |
| 5–8 GB | 800 | 200 | 12 | 12 |
| >8 GB | 1200 | 300 | 16 | 16 |

**验证输出要求：**审计时需记录配置输出，包括：
- OLS 调优值（例如 `grep -n "MaxConn" -n /usr/local/lsws/conf/httpd_config.conf`）。
- LSAPI 外部应用限制（例如 `grep -n "maxConns" -n /usr/local/lsws/conf/httpd_config.conf`）。
- PHP Worker 环境（例如 `grep -n "PHP_LSAPI_CHILDREN" -n /usr/local/lsws/conf/*`）。

### 自动合并策略（HLab）
仅在满足以下条件时允许自动合并：
1) 必要 CI 通过（`make ci`, `make smoke`），且
2) Gemini 审计员依据 `docs/AUDIT-CHECKLIST.md` 给出明确 PASS。
   PASS 必须具备机器可读形式：**Approve** 评审或 `audit-pass` 标签。
