# Logging and Masking Baseline

## Log Directory Strategy
- Default log directory: `logs/` under repository root.
- Override path: set `HZ_LOG_DIR`.
- Scripts should call `hz_prepare_log_dir` from `scripts/lib/logging.sh`.

## Masking Rules
- The following key patterns must be masked:
  - `*_PASS`
  - `*_TOKEN*`
  - `*_KEY*`
  - `*_SECRET*`
- Matching is case-insensitive by normalizing keys before pattern checks.
- Common variants (for example `FOO_KEY_ID`, `BAR_SECRET_NAME`, `baz_token_x`) must be masked.
- Use `hz_mask_kv_line` to mask `KEY=VALUE` lines before writing diagnostics or logs.

## Output Safety
- Do not print raw secret values in logs, diagnostics, or check output.
- Keep log messages in English with structured prefixes in calling scripts.
