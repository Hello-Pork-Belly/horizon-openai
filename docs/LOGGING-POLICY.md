# Logging and Masking Baseline

## Log Directory Strategy
- Default log directory: `logs/` under repository root.
- Override path: set `HZ_LOG_DIR`.
- Scripts should call `hz_prepare_log_dir` from `scripts/lib/logging.sh`.

## Masking Rules
- The following key patterns must be masked:
  - `*_PASS`
  - `*_TOKEN*`
  - `*_KEY`
  - `*_SECRET`
- Use `hz_mask_kv_line` to mask `KEY=VALUE` lines before writing diagnostics or logs.

## Output Safety
- Do not print raw secret values in logs, diagnostics, or check output.
- Keep log messages in English with structured prefixes in calling scripts.
