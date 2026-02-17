# Horizon (hz)

Horizon 是一个“契约驱动（Contract-First）”的无代理（Agentless）运维框架：同一套 `hz` 可以本地执行、远程执行、以及对主机组并发/滚动执行，并自动生成可审计的执行记录与汇总报表。

## 安装

从源码仓库安装（推荐）：

```bash
git clone https://github.com/Hello-Pork-Belly/horizon-openai.git
cd horizon-openai
./bin/hz version
```

一键安装（适合服务器）：

```bash
curl -fsSL https://raw.githubusercontent.com/Hello-Pork-Belly/horizon-openai/main/install.sh | bash
hz version
```

可选：安装指定版本（tag）：

```bash
HZ_INSTALL_REF=v1.0.0 curl -fsSL https://raw.githubusercontent.com/Hello-Pork-Belly/horizon-openai/main/install.sh | bash
```

## 快速上手

列出可用 recipes：

```bash
hz recipe list
```

本地 dry-run：

```bash
hz install security-host --dry-run
```

远程执行（Agentless / 瞬态 Runner）：

```bash
hz ping --target web01
hz install ols-wp --target web01 --dry-run
```

对主机组并发执行（@group）：

```bash
hz inventory resolve @web
HZ_MAX_JOBS=5 hz install security-host --target @web
```

滚动更新（分批 + 暂停）：

```bash
HZ_MAX_JOBS=5 hz install security-host --target @web --rolling 2 --pause 30
```

## Inventory 结构（Hosts / Groups）

Host：`inventory/hosts/web01.yml`

```yaml
HZ_CONNECTION_HOST: 10.0.0.1
HZ_CONNECTION_USER: ubuntu
HZ_CONNECTION_PORT: 22
HZ_CONNECTION_KEY: /home/me/.ssh/id_ed25519
```

Group：`inventory/groups/web.yml`

```yaml
hosts:
  - web01
  - web02
```

解析验证：

```bash
hz inventory resolve @web
```

## 报表（JSONL + HTML）

组执行结束会生成 `records/.../*.report.jsonl`，并在终端打印汇总表。

生成 HTML 仪表盘：

```bash
hz report html --latest
# 或
hz report html records/2026/02/17/<file>.report.jsonl
```

## Secrets（避免 Inventory 明文）

生成密钥（或自备强随机值）：

```bash
hz secret gen-key
export HZ_SECRET_KEY="...你的密钥..."
```

加密/解密：

```bash
hz secret encrypt "MyPassword"
hz secret decrypt "HZENC:..."
```

在 Inventory 中使用加密串（前缀 `HZENC:`），运行时会按需解密（需要 `HZ_SECRET_KEY`）。

## 自动化（Notify / Cron / Watchdog）

Webhook 通知（需要 `HZ_WEBHOOK_URL`）：

```bash
HZ_WEBHOOK_URL="https://..." hz notify --title "Backup" --message "Done" --status SUCCESS
```

系统级 cron 管理（写 `/etc/cron.d/hz-tasks`，需 root/sudo）：

```bash
sudo hz cron add --name nightly-backup --schedule "0 2 * * *" --user root --cmd "hz install backup-rclone --target @web"
sudo hz cron list
```

Watchdog（巡检 + 通知，可选有限自愈）：

```bash
sudo hz watch install --schedule "*/5 * * * *" --heal
hz watch run --heal
```

## Shell 补全

```bash
# bash
source <(hz completion bash)

# zsh
source <(hz completion zsh)
```
