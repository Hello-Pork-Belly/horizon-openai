# Phase 4 Plan: Autonomous Horizon

状态：T-031 规划冻结（Phase 4 启动文档）
版本目标：v0.5.x（Phase 4 产出不强绑定单一版本号，按任务逐步交付）

## 1. 目标与边界

Phase 4 目标：在保持“无 Agent（Agentless）”与“Contract-First”的前提下，让 hz 具备自动化与自愈能力，形成事件驱动的运维闭环：
1) 定时自动化（Cron Management）
2) 失败告警（Notification）
3) 基于诊断的自愈（Watchdog / Self-Healing）

非目标（Phase 4 不做）：
- 不引入长期驻留 daemon（除非作为可选增强，默认仍以 cron 驱动）
- 不做复杂的规则引擎（先做最小可用的“阈值/返回码 -> 动作”）
- 不做强依赖第三方 SaaS SDK（默认 Webhook JSON POST）

## 2. 总体架构

核心概念：Autonomy Loop（自治闭环）

[Scheduler] -> (hz cron) -> [Runner] -> (hz diagnose / hz install <healing-recipe>) -> [Reporting/Records] -> [Notifier] -> (Webhook/Email)

关键复用：
- T-021 records：所有执行均有落盘审计
- T-028 JSONL + 汇总表：可作为通知 payload 的数据源
- T-022 Remote Runner：watch/cron 可对组执行（Phase 3 的 group/parallel/rolling 可直接复用）

默认实现（Best Default）：
- 调度：/etc/cron.d/hz-tasks（root 级任务，集中管理，易审计）
- 告警：Webhook（HZ_WEBHOOK_URL），可扩展到 Email（复用 mail-gateway）
- 自愈：watch 任务周期性运行 diagnose，按“检查项->动作”映射触发修复 recipes（例如 heal-nginx / heal-mariadb）

备选实现（明确触发条件）：
- 若目标环境不允许改 /etc/cron.d（无 root / 受控主机）：切换到用户 crontab（触发：hz cron --user）
- 若需要更精细的时间/依赖/重试策略：切换到 systemd timers（触发：系统有 systemd 且允许写 unit）

## 3. CLI 设计（对外契约）

新增顶层命令（Phase 4 交付后）：
1) hz cron <action> ...
   - hz cron list
   - hz cron add --name <id> --schedule "<cron_expr>" --command "<hz ...>"
   - hz cron remove --name <id>
   - hz cron enable/disable --name <id>
   - 统一写入：/etc/cron.d/hz-tasks（默认）
   - 安全：写入前必须 dry-run 显示差异；默认不打印 secrets（仅显示命令骨架）

2) hz notify <action> ...
   - hz notify test (发送测试消息，不含 secrets)
   - hz notify send --file <records/.../*.report.jsonl>（从 report 生成摘要并推送）

3) hz watch <action> ...
   - hz watch once [--target <host|@group>]（执行一次：diagnose -> 判定 -> 触发修复）
   - hz watch install-cron（安装默认 watchdog cron 任务）
   - 默认只做“warn + notify”，自愈动作需显式开启：HZ_HEAL=1 或 --heal

## 4. 数据与配置来源

优先级（Last wins）：
1) inventory/group_vars/all.yml（全局默认）
2) inventory/hosts/<host>.yml（主机覆盖）
3) Shell Env（临时覆盖）

新增建议字段（不强制一次到位）：
- HZ_WEBHOOK_URL：Webhook 地址（建议放 inventory/group_vars/all.yml；不要提交真实值）
- HZ_NOTIFY_CHANNEL：可选，用于 payload 标签
- HZ_CRON_OWNER：默认 root
- HZ_WATCH_TARGET：默认 @all-nodes 或某个组
- HZ_WATCH_INTERVAL：默认每 5 分钟（cron 表达式形式）

安全约束：
- records/ 与 reporting 输出默认不包含 secrets；DEBUG 下也必须做 mask（至少对 *_PASSWORD / *_KEY / *_SECRET）
- 通知 payload 只发送摘要与目标、状态、耗时、错误短句，不发送环境变量值

## 5. 自愈策略（最小可用版）

判定输入：
- hz diagnose 的退出码 + 关键检查项标记（建议逐步把 diagnose 输出标准化为可机器解析的“key=status”行；Phase 4 初期可先按退出码/关键词）

动作映射（v1）：
- nginx down -> systemctl restart nginx
- redis down -> systemctl restart redis-server
- mariadb down -> systemctl restart mariadb
- disk high -> notify only（不自动清理）

执行方式：
- 动作以 recipe 形式封装（healing recipes），保持“所有变更都走 hz install <recipe>”的统一入口与审计。

## 6. 任务拆分（Phase 4 的原子任务）

T-032 Notification Layer（lib/notify.sh）
- 目标：提供 notify_send(payload) 与 notify_from_report(report.jsonl)
- 输入：HZ_WEBHOOK_URL（必需），可选 HZ_NOTIFY_CHANNEL
- DoD：失败任务能自动发通知（至少在 orchestrator/reporting 结束时可被调用）
- 安全：默认 mask；禁止把环境变量 dump 到 webhook

T-033 Cron Manager（hz cron）
- 目标：集中管理 /etc/cron.d/hz-tasks（支持 add/list/remove/enable/disable）
- DoD：hz cron add 后系统能按期触发；hz cron list 可读；hz cron remove 干净回滚
- 安全：写文件权限 0644，owner root；写入前必须 preview；需要 root 时明确报错

T-034 Watchdog / Self-Healing（hz watch）
- 目标：实现“诊断->通知->（可选）修复”的一次执行与 cron 安装
- DoD：hz watch once 能对单机/组执行；失败会产生 records + 通知；--heal 时可执行至少一种修复
- 安全：默认不自愈（需要显式开关），避免误操作

T-035 Hardening（可选）
- 通知重试/退避、webhook 超时、payload size 限制
- Watchdog 的并发/rolling 策略复用（Phase 3 已有）

## 7. 验证策略（CI/本地）

- 单元级：对 notify 的 payload 生成做纯文本断言（不发真实网络请求，使用 mock URL 或跳过）
- 集成级：watch once 在 localhost 上运行 diagnose（容错：无服务也不 crash）
- 回归：确保 Phase 3 orchestrator/reporting 行为不退化（make ci）

## 8. 风险与缓解

风险：cron 写入权限、误触发自愈、通知泄密、网络抖动导致误报警
缓解：
- 默认 dry-run + preview
- 默认只 notify 不 heal
- 全链路 mask secrets
- webhook 失败不影响主任务返回码（notify 作为 best-effort，但需记录 WARN）
