SHELL := /bin/bash

.PHONY: lint smoke ci

lint:
	bash -c 'shopt -s globstar; shellcheck scripts/**/*.sh'

smoke:
	bash -n scripts/clean_node.sh
	bash scripts/clean_node.sh --dry-run

ci: lint smoke
