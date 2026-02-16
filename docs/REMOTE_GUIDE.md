# Remote Guide (Agentless Remote Execution)

本指南描述 Horizon `hz` 的远程执行能力（Phase 2 / v0.3.0）：控制机（Controller）通过 SSH 将“最小执行包（Transient Runner Payload）”传送到目标机（Target），在 `/tmp` 中解压运行，执行结束后清理，不需要在目标机预装 `hz` 或常驻 Agent。

## 1. 核心概念：Transient Runner

执行路径（Pack → Ship → Exec → Clean）：
1) Pack：控制机打包 `bin/hz`、`lib/`、`inventory/`、`recipes/<recipe>/`（以及必要的 `tools/`）为 tar.gz。
2) Ship：通过 SCP 发送到目标机 `/tmp/hz_run_<run_id>/payload.tar.gz`。
3) Exec：目标机在 `/tmp/hz_run_<run_id>/work/` 解压并执行 `./bin/hz install <recipe> --local-mode --headless`。
4) Clean：默认删除 `/tmp/hz_run_<run_id>`。排障可用 `HZ_REMOTE_KEEP=1` 保留。

## 2. 前置条件

控制机需要：
- bash
- ssh/scp 客户端
- 本仓库代码与 `bin/hz`

目标机需要：
- sshd 可连接
- bash + tar
- 具备运行 recipe 的权限（通常需要 sudo 或 root）

## 3. Inventory：Host 连接字段（Phase 2）

在 `inventory/hosts/<alias>.yml` 中加入以下扁平键（KEY 必须为大写+下划线）：

必填：
- `HZ_CONNECTION_HOST`: 目标 IP 或 DNS

可选：
- `HZ_CONNECTION_USER`: SSH 用户（默认当前用户）
- `HZ_CONNECTION_PORT`: SSH 端口（默认 22）
- `HZ_CONNECTION_KEY`: 私钥路径（可选，推荐使用绝对路径）

示例：`inventory/hosts/web01.yml`
```yaml
HZ_CONNECTION_HOST: "10.0.0.10"
HZ_CONNECTION_USER: "ubuntu"
HZ_CONNECTION_PORT: "22"
HZ_CONNECTION_KEY: "/Users/you/.ssh/id_ed25519"

# 同时可放 recipe 需要的变量（建议敏感值用外部注入）
WP_DOMAIN: "example.com"
WP_EMAIL: "admin@example.com"
```

安全约束：
- 不要把私钥内容写进 inventory。
- 不建议把明文密码/secret 直接写进 inventory（推荐通过环境变量或更安全的密钥管理注入）。

## 4. SSH 相关环境变量

- `HZ_SSH_KEY=/path/to/key`：强制使用指定私钥（优先级高于 inventory 的 key 字段）。
- `HZ_SSH_ARGS="...extra flags..."`：额外 ssh/scp 参数（例如跳板机 `-J jump`、非标准端口 `-p 2222` 等）。
- `HZ_SSH_STRICT_HOST_KEY_CHECKING=accept-new|yes|no`：host key 策略（默认 accept-new）。
- `HZ_SSH_CONNECT_TIMEOUT=10`：连接超时秒数。

## 5. 基础连通性验证

1. 透传 target（不经过 inventory）：

```bash
./bin/hz ping --target user@1.2.3.4
```

2. 使用 alias（会读取 inventory/hosts/<alias>.yml）：

```bash
./bin/hz ping --target web01
```

## 6. 远程安装（Remote Install）

命令形态：

```bash
./bin/hz install <recipe> --target <alias|user@host> [--host <inventory_host_alias>] [--dry-run]
```

示例（推荐：target 用 alias）：

```bash
./bin/hz install security-host --target web01 --dry-run
./bin/hz install ols-wp --target web01 --dry-run
```

说明：
- `--target` 指定“连接目标”（远程机器）。
- `--host` 指定“配置 host”（用于加载 inventory 变量）。通常你会让两者一致：`--target web01 --host web01`。
- `--dry-run` 会尽量走非破坏路径（取决于 recipe 是否遵循 HZ_DRY_RUN 约定）。

## 7. 审计记录（Session Recording）

默认情况下，关键命令输出会被录制到控制机本地：

- 路径：`records/YYYY/MM/DD/`
- 可用 `HZ_NO_RECORD=1` 关闭录制（临时调试用，不建议在生产环境关闭）。

建议：
- 需要保留彩色输出，可用 `less -R <logfile>` 浏览（若日志中包含 ANSI）。

## 8. 故障排查

1. SSH 失败：
- 先 `./bin/hz ping --target <alias|user@host>`
- 检查 `HZ_SSH_ARGS`、端口、跳板机、权限与 host key 策略。

2. 远端执行失败但需要现场：
- 设置 `HZ_REMOTE_KEEP=1` 重跑一次，保留 `/tmp/hz_run_<id>` 供排查。
- 排查结束后手动删除该目录。

3. Contract 缺变量：
- 先检查 inventory 是否加载了对应变量
- 再检查 shell 环境变量是否覆盖（shell 优先级最高）

## 9. 安全建议（生产默认）

- host key：生产建议 `HZ_SSH_STRICT_HOST_KEY_CHECKING=yes` 并维护 known_hosts。
- 私钥：使用 ssh-agent 或最小权限私钥；避免把 key 路径写进共享 inventory。
- secrets：避免明文落盘；若必须在 inventory 中存储，建议引入 SOPS/age（后续 Phase 3 议题）。
