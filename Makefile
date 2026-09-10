# Trendy Toys Canada — static site. There is no build step; these are just
# conveniences for working on it locally.

PORT ?= 8000
HOST ?= 127.0.0.1
URL  := http://$(HOST):$(PORT)/

.PHONY: help serve open stop check

# Bare `make` prints usage rather than doing anything.
.DEFAULT_GOAL := help

help: ## Show available targets
	@echo "Trendy Toys Canada — static site (no build step)"
	@echo
	@echo "Usage: make <target>"
	@echo
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk -F':.*?## ' '{printf "  \033[1m%-8s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Override the port with: make serve PORT=9000"

serve: ## Serve the site locally on port 8000 (Ctrl-C to stop)
	@echo "Serving $(URL) — press Ctrl-C to stop"
	@python3 -m http.server $(PORT) --bind $(HOST) --directory .

open: ## Open the site in your default browser (start `make serve` first)
	@xdg-open $(URL) >/dev/null 2>&1 || open $(URL) >/dev/null 2>&1 || \
		echo "Couldn't open a browser — go to $(URL)"

# Matched by port rather than by command line: a `pkill -f` pattern broad enough
# to catch the server also matches the shell running this recipe.
stop: ## Kill a stray server left running on that port
	@fuser -k $(PORT)/tcp >/dev/null 2>&1 && echo "Stopped server on $(PORT)" \
		|| echo "No server running on $(PORT)"

check: ## Sanity-check the JS syntax and that every #anchor has a target
	@node --check js/main.js && echo "js/main.js: syntax OK"
	@missing=0; \
	for a in $$(grep -o 'href="#[a-z-]*"' index.html | sed 's/href="#//;s/"//' | sort -u); do \
		grep -q "id=\"$$a\"" index.html || { echo "missing anchor target: #$$a"; missing=1; }; \
	done; \
	[ $$missing -eq 0 ] && echo "anchors: all resolve"
