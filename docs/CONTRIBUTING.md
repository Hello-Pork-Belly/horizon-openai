# Contributing

## Required Local Validation
- Run `make check` before opening a pull request.
- `make ci` is kept as an alias and must produce the same result.

## CI Policy
- CI check workflow runs on GitHub-hosted runners only.
- Do not introduce SSH-based or other remote execution into the check workflow.
- Keep the workflow entrypoint single and stable (`make check`).

## Vendor-Neutral Content Gate
- The repository enforces a vendor-neutral wording gate across tracked files.
- Gate failures are reported as `path:line`.
- Do not add platform/vendor names to docs, comments, examples, or script outputs.

## Secrets Policy
- Never commit tokens, passwords, private keys, or `.env` credential files.
- Never print secrets in logs or CI output.
- Use repository/organization secrets for automation inputs.
