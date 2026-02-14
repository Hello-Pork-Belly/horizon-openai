SHELL := /bin/bash

.PHONY: check lint lint-strict smoke ci vendor-neutral

lint-strict: lint

lint:
	bash -c 'set -euo pipefail; while IFS= read -r script_file; do if [[ "$${script_file}" == archive/upstream-20260215/oneclick/* ]]; then shellcheck -S error "$${script_file}"; else shellcheck "$${script_file}"; fi; done < <(find tools recipes modules archive/upstream-20260215/oneclick -type f -name "*.sh" | sort)'

smoke:
	bash -n tools/clean_node.sh
	bash tools/clean_node.sh --dry-run

vendor-neutral:
	bash tools/check/vendor_neutral_gate.sh

check:
	bash tools/check/run.sh

ci: check
