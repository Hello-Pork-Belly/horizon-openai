# LOMP-Lite Scope

## English (primary)

### In scope
- OpenLiteSpeed (OLS) web server configuration.
- LSPHP/LSAPI worker limits and tuning.
- MariaDB or MySQL service configuration (resource limits, backups).
- PHP runtime settings relevant to concurrency and memory.
- Systemd service resource controls (`MemoryHigh`, `CPUQuota`).
- Basic OS observability: disk, memory, and failed unit checks.

### Out of scope
- Multi-tenant SaaS configuration or billing logic.
- Application-layer feature development.
- Non-OLS web servers unless explicitly approved.
- Long-running data migrations not tied to LOMP-Lite operations.

### Required audit evidence
- OLS + LSAPI concurrency settings per RAM tier.
- Service resource limits set for systemd units.
- `make ci` and `make smoke` outputs.

## 中文（次要）

### 范围内
- OpenLiteSpeed (OLS) 配置。
- LSPHP/LSAPI 工作进程限制与调优。
- MariaDB/MySQL 服务配置（资源限制、备份）。
- 与并发/内存相关的 PHP 运行时设置。
- systemd 服务资源控制（`MemoryHigh`, `CPUQuota`）。
- 基本系统可观测性：磁盘、内存、失败单元检查。

### 范围外
- 多租户 SaaS 配置或计费逻辑。
- 应用层功能开发。
- 未明确批准的非 OLS Web 服务器。
- 与 LOMP-Lite 无关的长时间数据迁移。

### 必要审计证据
- 按内存档设置的 OLS + LSAPI 并发。
- systemd 单元资源限制设置。
- `make ci` 与 `make smoke` 输出。
