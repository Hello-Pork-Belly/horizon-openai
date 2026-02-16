# Horizon (hz)

Horizon 是一个以 `hz` 为唯一入口的运维自动化框架，具备 Contract-First、Inventory 注入、统一日志、可重放审计记录（records/），并支持 Agentless 远程执行（Phase 2）。

## Quick Start

1) 查看帮助
```bash
./bin/hz help
```

2) 本地运行（示例）

```bash
./bin/hz install security-host --dry-run
```

3) Inventory 注入（本地）

```bash
# 读取 inventory/group_vars/all.yml + inventory/hosts/web01.yml
./bin/hz install ols-wp --host web01 --dry-run
```

## Remote Management (v0.3.0)

核心能力：控制机通过 SSH 将最小执行包传到目标机 `/tmp` 执行，目标机不需要预装 `hz`，执行后默认清理。

1) 配置目标机连接信息：`inventory/hosts/<alias>.yml`

```yaml
HZ_CONNECTION_HOST: "10.0.0.10"
HZ_CONNECTION_USER: "ubuntu"
HZ_CONNECTION_PORT: "22"
HZ_CONNECTION_KEY: "/Users/you/.ssh/id_ed25519"
```

2) 验证连通性

```bash
./bin/hz ping --target web01
```

3) 远程执行（dry-run）

```bash
./bin/hz install security-host --target web01 --host web01 --dry-run
```

更多细节见：`docs/REMOTE_GUIDE.md`

## Recipes

使用 `hz recipe list` 查看可用 recipes：

```bash
./bin/hz recipe list
```

常见：
- security-host
- ols-wp
- ols-wp-maintenance
- lomp-lite / lnmp-lite
- hub-data / hub-main
- mail-gateway
- backup-rclone

## Diagnostics

```bash
./bin/hz diagnose
```

## Audit Records

默认情况下，关键命令输出会录制到：
- `records/YYYY/MM/DD/`

可用 `HZ_NO_RECORD=1` 临时关闭录制：

```bash
HZ_NO_RECORD=1 ./bin/hz install security-host --dry-run
```

## Development

运行 CI 同等检查：

```bash
make ci
```

版本：

```bash
./bin/hz version
```
