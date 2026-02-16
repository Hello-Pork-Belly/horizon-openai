# Inventory Schema

Inventory 用于向 recipes 注入配置，并在 Phase 2/3 中承担目标解析与编排输入。

## 1) Host Files

路径：`inventory/hosts/<alias>.yml`

约束：Phase 1/2/3 MVP 仅保证“扁平 KEY: VALUE”映射（KEY 推荐全大写下划线）。

### 1.1 连接字段（Phase 2）

以下字段用于远程连接解析（alias -> user@host + ssh 参数）：

- `HZ_CONNECTION_HOST` (required): IP / DNS
- `HZ_CONNECTION_USER` (optional): default current user
- `HZ_CONNECTION_PORT` (optional): default 22
- `HZ_CONNECTION_KEY` (optional): private key path (controller-side)

示例：
```yaml
HZ_CONNECTION_HOST: "10.0.0.10"
HZ_CONNECTION_USER: "ubuntu"
HZ_CONNECTION_PORT: "22"
HZ_CONNECTION_KEY: "/Users/you/.ssh/id_ed25519"
```

### 1.2 业务变量（Recipes）

同一 host 文件也可放置 recipes 所需环境变量（例如 WP_DOMAIN 等）。注意：避免把明文 secret 长期写入仓库；推荐通过环境变量注入或后续引入加密方案（Phase 3+）。

## 2) Global Defaults

路径：`inventory/group_vars/all.yml`

用于全局默认值（所有 host 共享）。

## 3) 优先级（Last Wins）

最终注入到 recipe 的变量优先级（高 -> 低）：

1. Shell 环境变量（用户临时覆盖）
2. Host YAML：`inventory/hosts/<alias>.yml`
3. Global YAML：`inventory/group_vars/all.yml`

## 4) Groups (Phase 3 / T-025)

路径：`inventory/groups/<group>.yml`

MVP 结构（T-025）：

```yaml
hosts:
  - host-a
  - host-b
vars:
  SOME_VAR: value   # 预留（T-025 暂不使用）
```

说明：

* `hosts`：必须为 host alias 列表，对应 `inventory/hosts/<alias>.yml`
* `vars`：预留给后续（T-026+）作为 group-level vars（尚未启用）
