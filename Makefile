SHELL := /bin/bash

HZ := ./bin/hz

.PHONY: ci check lint hz-version recipes-dry-run

ci: check

check: hz-version lint recipes-dry-run
	@echo "[OK] make check passed"

hz-version:
	@set -euo pipefail; \
	test -x "$(HZ)" || { echo "[ERROR] $(HZ) not executable"; exit 1; }; \
	hz_ver="$$( $(HZ) --version )"; \
	file_ver="$$( cat VERSION )"; \
	if [[ "$$hz_ver" != "$$file_ver" ]]; then \
	  echo "[ERROR] version mismatch: hz=$$hz_ver VERSION=$$file_ver"; \
	  exit 1; \
	fi; \
	echo "[OK] version $$hz_ver"

lint:
	@set -euo pipefail; \
	bash -n "$(HZ)"; \
	if command -v shellcheck >/dev/null 2>&1; then \
	  while IFS= read -r f; do \
	    shellcheck -e SC1091 "$$f"; \
	  done < <(find bin lib tools recipes -type f -name "*.sh" ! -path "lib/baseline/baseline*.sh" | sort); \
	else \
	  echo "[WARN] shellcheck not found; skipping"; \
	fi

recipes-dry-run:
	@set -euo pipefail; \
	found=0; \
	while IFS= read -r c; do \
	  found=1; \
	  name="$$(basename "$$(dirname "$$c")")"; \
	  echo "[INFO] dry-run install recipe=$$name"; \
	  if ! HZ_DRY_RUN=1 MAINTENANCE_ACTION="$${MAINTENANCE_ACTION:-backup}" "$(HZ)" recipe "$$name" install; then \
	    echo "[WARN] dry-run install failed for recipe=$$name; fallback to check"; \
	    HZ_DRY_RUN=1 MAINTENANCE_ACTION="$${MAINTENANCE_ACTION:-backup}" "$(HZ)" recipe "$$name" check; \
	  fi; \
	done < <(find recipes -mindepth 2 -maxdepth 2 -type f -name contract.yml | sort); \
	if [[ "$$found" -eq 0 ]]; then \
	  echo "[WARN] no recipes found (recipes/*/contract.yml)"; \
	fi
