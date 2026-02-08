SHELL := /bin/bash

.PHONY: check lint lint-strict smoke ci vendor-neutral

lint-strict: lint

lint:
	bash -c 'find scripts recipes modules upstream/oneclick -type f -name "*.sh" -print0 | xargs -0 -n1 shellcheck'

smoke:
	bash -n scripts/clean_node.sh
	bash scripts/clean_node.sh --dry-run

vendor-neutral:
	bash scripts/check/vendor_neutral_gate.sh

check:
	bash scripts/check/run.sh

ci: check
