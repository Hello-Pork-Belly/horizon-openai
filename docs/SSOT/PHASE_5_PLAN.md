# Phase 5 Plan: Operations & Interface (Target: v1.0.0)

Status: Draft (SSOT)  
Owner: Planner (GPT)  
Date: 2026-02-17

## 0. Goals (What Phase 5 Delivers)

Phase 5 的目标是把 Horizon 从“可用的运维引擎”提升为“生产就绪的产品形态”，重点补齐可见性、安全性、易用性与分发能力：

1) Visual Reporting：提供 `hz report html`，把 `records/**/*.jsonl` 汇总成静态 HTML 仪表盘（可本地打开/归档）。  
2) Secret Management：提供 `hz secret encrypt/decrypt`，允许 Inventory 中保存密文而非明文，并在运行时解密注入。  
3) Shell Integration：提供 `hz completion`（bash/zsh），提升可用性与命令发现。  
4) Distribution：提供标准 `install.sh`（curl | bash 安装），并与 Release 资产/校验和对齐。  
5) Final Polish：完成文档、CI 验证、版本治理，发布 v1.0.0。

## 1. Non-Goals (Explicitly Not in Scope)

- 不做常驻 Agent（仍保持 agentless）。  
- 不引入外部数据库/服务作为运行时依赖（仍以文件系统 + ssh 为主）。  
- 不做“集中式 Web UI”（Phase 5 只做静态 HTML 报告，不做服务端）。  
- 不做企业级 KMS 集成（仅做本地对称加密方案 + 清晰边界）。

## 2. Architecture (Best Default)

### 2.1 HTML Report Engine (Best Default)
Option 1 (Default): Python3 标准库渲染（controller 侧）  
- 输入：`records/**/session_*.report.jsonl`（Phase 3 的 JSONL）  
- 输出：`records/**/session_*.report.html`（同目录落地）  
- 形态：单文件 HTML（内联 CSS，少量 JS 可选）  
- 功能：按 target 展示 SUCCESS/FAILURE/TIMEOUT、耗时、日志路径；支持过滤与折叠详情（可选）。

切换策略：  
- 若 controller 环境缺少 python3（不符合项目默认假设），降级为 Option 2（纯 bash 生成极简 HTML）。

Option 2: Bash 拼接模板（降级）  
- 只输出表格与链接/路径，不做复杂交互。

### 2.2 Secret Management (Best Default)
Option 1 (Default): OpenSSL 对称加密 + Inventory 值内嵌密文标记  
- 明文禁止落库：Inventory 允许出现 `ENC[...]` 形式的密文值。  
- Key 来源：运行时环境变量 `HZ_SECRET_KEY`（或交互式 prompt；但自动化场景必须支持 env）。  
- 加密算法建议：AES-256-GCM + PBKDF2 + salt（避免弱口令直接映射）。  
- 解密时机：controller 在 inventory load 阶段解密，注入到 recipe 子进程环境变量；默认日志必须 masking。

切换策略：  
- 若目标平台缺少 openssl 或 openssl 过旧不支持 GCM：切换 Option 2（GPG/age，按可用性优先）。  
- 但“Best Default”要求零新增依赖，因此优先 openssl。

### 2.3 Shell Completion (Best Default)
- `hz completion bash|zsh` 输出补全脚本到 stdout。  
- 动态候选：subcommands + recipes + groups。  
- 机制：用 `hz help`/内部命令输出作为单一真源，避免多处维护。

### 2.4 Distribution (Best Default)
- 发布资产以“目录包”方式分发（包含 `bin/ lib/ tools/ recipes/`），安装到 `/opt/hz`，再软链接 `/usr/local/bin/hz`。  
- `install.sh`：下载 release tarball + 校验和（sha256），解压到目标目录，设置权限。  
- 不引入包管理器专用逻辑（vendor neutral）。

## 3. Data Contracts (Reporting Compatibility)

Phase 5 的 HTML 报告以 Phase 3 JSONL 为单一输入真源。建议冻结字段（最小集合）：
- session_id
- command (install/run/diagnose)
- target (alias 或 resolved)
- status (SUCCESS/FAILURE/TIMEOUT/ABORTED)
- rc (exit code)
- duration_s
- message (简短摘要，禁止包含 secrets)
- logfile (records 路径)

兼容策略：新增字段只追加不破坏；渲染器忽略未知字段。

## 4. Security Considerations

- 默认 INFO 不允许输出 secrets；DEBUG 也必须对已知敏感 key 做 masking。  
- 密文格式必须可识别（如 `ENC[...]`），防止误把密文当明文打印。  
- install.sh 必须支持校验（sha256），避免 silent tampering。  
- 报告 HTML 不嵌入 secrets，不嵌入完整日志内容（默认只链接/指向日志文件路径；可选模式才内嵌并仍需 masking）。

## 5. Task Breakdown (Atomic Tasks)

### T-037 HTML Reports (`hz report html`)
Deliverables:
- 新增 report 命令：从 session JSONL 生成 HTML。
- 文档：如何定位 session、如何生成 latest 报告。
DoD:
- `hz report html --latest` 生成可打开的 html；无 secrets 泄露。

### T-038 Secrets (`hz secret encrypt/decrypt`)
Deliverables:
- `hz secret encrypt`：把指定 key 的值转为 `ENC[...]`。
- `hz secret decrypt`：解密并输出到 stdout（默认不打印到 INFO 日志）。
- inventory loader：识别 `ENC[...]` 并在有 key 时解密注入。
DoD:
- 未提供 `HZ_SECRET_KEY` 时：不失败（除非 contract 要求该值）；提示如何提供 key。
- 提供 key 时：`hz install ...` 可自动解密注入。

### T-039 UX Polish (Completion + Installer)
Deliverables:
- `hz completion bash|zsh`
- `install.sh` + 校验和策略文档
- README 增加“安装/补全/报告/加密”章节
DoD:
- 本地安装后 `hz version` 正常；补全脚本可生效。

### T-040 Final Release v1.0.0
Deliverables:
- 版本号、Phase 状态、changelog/upgrade notes
- CI 里增加对 `install.sh` 的最小 smoke test（只做下载/解压/版本输出）
DoD:
- Tag `v1.0.0`；CI 全绿；文档可自洽。

## 6. Assumptions / Decisions (To be logged as D-036 in DECISIONS.md)
- A1: Controller 侧保证有 bash + coreutils + python3（用于 report 渲染的 Best Default）。  
- A2: openssl 在主流目标环境可用；若不可用则允许切换到 GPG/age（不作为默认）。  
- A3: secrets 默认不落库明文；report/console 默认 masking。  
注：本 PR allowlist 不包含 DECISIONS.md，需由 Commander 另起 PR 补登记 D-036。
