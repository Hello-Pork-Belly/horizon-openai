SHELL := /bin/bash

.PHONY: check lint lint-strict smoke ci vendor-neutral

lint-strict: lint

lint:
	bash -c 'set -euo pipefail; while IFS= read -r script_file; do if [[ "$${script_file}" == upstream/oneclick/* ]]; then shellcheck -S error "$${script_file}"; else shellcheck "$${script_file}"; fi; done < <(find scripts recipes modules upstream/oneclick -type f -name "*.sh" | sort)'

smoke:
	bash -n scripts/clean_node.sh
	bash scripts/clean_node.sh --dry-run

vendor-neutral:
	bash scripts/check/vendor_neutral_gate.sh

check:
	bash scripts/check/run.sh

ci: check
