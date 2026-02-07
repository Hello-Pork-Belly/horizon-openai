SHELL := /bin/bash

.PHONY: check lint lint-strict smoke ci vendor-neutral

lint-strict: lint

lint:
	bash -c 'shopt -s globstar; shellcheck scripts/**/*.sh'

smoke:
	bash -n scripts/clean_node.sh
	bash scripts/clean_node.sh --dry-run

vendor-neutral:
	bash scripts/check/vendor_neutral_gate.sh

check:
	bash scripts/check/run.sh

ci: check
