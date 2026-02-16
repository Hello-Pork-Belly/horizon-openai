# Phase 3 Plan: Fleet Orchestration (v0.4.x)

Status: Draft (SSOT)
Owner: Planner (GPT)
Date: 2026-02-17

## 0. Goals (What Phase 3 Delivers)

Phase 3 的目标是把 Horizon 从“单目标远程执行”（Phase 2）提升为“机队编排系统”：

1) Group Management：可在 Inventory 中定义主机组（web-servers/db-cluster 等）。
2) Parallel Execution：对组内主机并行执行命令（默认并发 N）。
3) Rolling Updates：按策略滚动执行（一次 1 台或 batch，含 pause）。
4) Aggregated Reporting：将分散的执行结果汇总为单一报告（成功/失败/耗时/日志路径）。

非目标（本阶段不做）：
- 不引入常驻 Agent（仍保持 Agentless）。
- 不引入复杂分布式队列或数据库（保持 Bash + 文件系统为主）。
- 不实现“跨 host 的事务回滚”（只做 best-effort 报告与可重跑）。

## 1. Architecture (Best Default)

核心概念：The Orchestrator（编排器）

- Controller 端 `hz` 负责：
  - 根据 Inventory 将组解析为 target 列表（alias → user@host + ssh 参数）。
  - 为每个 target 启动一个“远程瞬态执行”（Phase 2 的 transient runner）。
  - 收集每个 target 的 exit code、输出日志路径、开始/结束时间。
  - 输出聚合摘要（并写入 records 报告文件）。

- Target 端不变：仍只接收 payload、在 /tmp 解压执行、默认清理。

并发模型（Best Default）：
- Bash job control：每个 target 一个后台 job（`remote_execute_recipe ... &`），主进程用 `wait` 收割。
- 并发限制：用“简单信号量”控制最大并发 `HZ_PARALLELISM`（默认 4）。
- 不使用 `xargs -P`：避免平台差异与参数转义复杂度；纯 Bash 可控且便于捕获每个 job 的 metadata。

滚动模型（Rolling）：
- 顺序执行或分批执行（batch）。
- 参数：`--rolling N` 表示每批 N 台（默认 1）；`--pause SECONDS` 表示批次间暂停（默认 0）。
- Rolling 是 Parallel 的特例：每个 batch 内仍可并行（最多 N 或 `HZ_PARALLELISM`，取 min）。

输出聚合（Reporting）：
- 每个 target 的执行会已有 session recording（records/...）。Phase 3 额外生成一个“编排报告文件”：
  - `records/YYYY/MM/DD/<ts>_<group>_<command>.report.jsonl`（JSON Lines）
  - 以及 `...report.txt`（人类可读摘要）

## 2. Inventory Design (Groups)

新增目录：
- `inventory/groups/<group>.yml`

文件格式（扁平 YAML，Best Default）：
```yaml
# inventory/groups/web-servers.yml
members:
  - web01
  - web02
  - web03
```

约束：
- members 为 host alias 列表，对应 `inventory/hosts/<alias>.yml`。
- 不在 group 文件中存连接细节；连接细节只在 host 文件中维护（单一来源）。

兼容/扩展（后续可选）：
- 允许 group 引用 group（递归展开）：`members: [web01, "@db-cluster"]`（Phase 3 后半段再做）。
- 允许在 host 文件里加 tag（不作为默认方案）。

## 3. CLI/UX Design (User Experience)

新增能力（Phase 3 目标）：

A) Group execution for install:
- `hz install <recipe> --group <group> [--rolling N] [--pause S] [--parallel N] [--fail-fast] [--target-mode]`

参数说明：
- `--group <group>`：从 inventory/groups 解析 target 列表。
- `--parallel N`：最大并发（默认 4；也可用 env `HZ_PARALLELISM`）。
- `--rolling N`：滚动批大小（默认 0 表示关闭 rolling；1 表示单台滚动）。
- `--pause S`：批次间暂停秒数。
- `--fail-fast`：任一失败则停止后续 batch（默认关闭；默认策略是“尽量跑完并汇总”）。
- `--target-mode`：控制执行目标：remote-only/local-only/auto（默认 auto，兼容 Phase 2）。

输出格式（建议）：
- 控制台显示“进度条风格摘要”，每个 target 一行：RUNNING/OK/FAIL + rc + logfile。
- 最后输出汇总：成功数量、失败列表、报告文件路径。

B) Group ping:
- `hz ping --group <group>`（并发测试连接，输出 OK/FAIL）

## 4. Concurrency Details (Implementation Notes)

并发信号量（伪代码）：
- 维护一个计数器 `running=0`
- 启动 job 前，若 `running >= parallel`，则 `wait -n`（Bash 4.3+）或轮询等待任一 job 完成。
- 为兼容较老 Bash：采用“PID 列表 + wait 任意一个”的轮询：
  - 遍历 PID 列表，用 `kill -0 $pid` 判断是否仍存活，回收已结束的 wait。

每个 job 需要捕获：
- alias（web01）
- resolved target（user@host）
- rc（退出码）
- logfile（控制机记录文件）
- start/end epoch

输出聚合：
- JSONL 每行一条结果，便于后续解析/可视化。

## 5. Task Breakdown (Atomic Tasks)

T-025 Group Inventory (MVP)
- 新增 `inventory/groups/` 与解析函数：
  - `inventory_list_group_members <group>` → 输出 alias 列表（每行一个）
- 新增 `hz ping --group <group>`（并发 N 可配置）
DoD:
- group 文件存在时能列出成员；不存在时报错 exit 1。

T-026 Parallel Orchestrator (Install on Group)
- `hz install <recipe> --group <group> --parallel N`
- 并发执行 remote runner，汇总 exit code（若任何失败，最终 exit 1）
DoD:
- 对一个 3-host group 并发运行，输出每个 host 的 OK/FAIL。

T-027 Rolling Updates
- `--rolling N --pause S --fail-fast`
- batch 执行策略 + 可选 fail-fast
DoD:
- rolling=1 时严格顺序；rolling=2 时分批；pause 生效。

T-028 Aggregated Reporting
- 生成 report.jsonl + report.txt（写入 records/...）
- 控制台结尾打印报告路径与失败列表
DoD:
- 每次 group run 都生成报告文件；报告包含 rc/logfile/duration。

T-029 UX Hardening
- 输出稳定、可读；错误信息统一；对超时/中断友好（Ctrl-C 触发清理与报告落盘）。
DoD:
- Ctrl-C 时生成“partial report”，并标记 aborted。

## 6. Security Considerations

- 默认不在 INFO 输出 secrets；DEBUG 也应遵循 masking（沿用现有 log masking）。
- 并发执行会同时处理多台机器，报告文件可能包含更多元数据；禁止写入明文密码。
- SSH host key 策略由已有 transport 层控制；生产建议 `StrictHostKeyChecking=yes`。

## 7. Milestones / Versioning (Proposal)

- v0.4.0：T-025 + T-026（Group + Parallel MVP）
- v0.4.1：T-027（Rolling）
- v0.4.2：T-028（Aggregated Reporting）
- v0.4.3：T-029（Hardening）
