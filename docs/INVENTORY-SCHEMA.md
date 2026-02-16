# Inventory Schema Baseline

## Paths
- `inventory/group_vars/all.yml`
- `inventory/hosts/*.yml`
- `inventory/sites/*.yml`

## Phase 1: Env Injection (flat keys)
Horizon 的 Inventory Loader 目前支持“扁平 key: value”并导出为环境变量（KEY 必须为大写+下划线）。
示例：
- `WP_DOMAIN: example.com`
- `DB_PASSWORD: "..."`（注意：敏感值建议通过外部 secret 注入而不是写入 inventory）

## Phase 2: Remote Connection Keys (Target Selection)

为支持 `hz ping --target <alias>` / 后续 `hz run --host <alias>`，允许在 `inventory/hosts/<alias>.yml` 中声明以下连接字段（同样要求扁平大写 key）。

Required:
- `HZ_CONNECTION_HOST`: 目标主机名或 IP（必填）

Optional:
- `HZ_CONNECTION_USER`: SSH 用户（默认：当前用户）
- `HZ_CONNECTION_PORT`: SSH 端口（默认：22）
- `HZ_CONNECTION_KEY`: 私钥路径（可选；仅路径，不是密钥内容）

兼容旧命名（若存在会被读取）：
- `HZ_HOST_ADDR` / `HZ_HOST_USER` / `HZ_HOST_PORT` / `HZ_HOST_KEY_PATH`

解析规则：
1. 若存在 `inventory/hosts/<alias>.yml`：解析上述字段，构造 `user@host`，并导出：
   - `HZ_RESOLVED_TARGET`
   - `HZ_SSH_KEY`（来自 key 字段，且仅在 shell 未显式设置时）
   - `HZ_SSH_ARGS`（补齐 `-p <port>`，且仅在未显式提供 `-p` 时）
2. 若 hosts 文件不存在：认为输入已是 `user@host` 或 `host`，直接透传。

安全约束：
- Inventory 不应保存密码/token/secret 等敏感信息。
- `HZ_CONNECTION_KEY` 仅允许保存“路径”，不得把私钥内容写入 inventory。
