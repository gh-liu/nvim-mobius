# nvim-mobius Makefile
# Targets: test, .deps, helptags

MINI_URL ?= https://github.com/nvim-mini/mini.nvim
MINI_DIR = .deps/mini.nvim

.PHONY: test helptags
test: .deps
	nvim --headless -u tests/minitest_setup.lua -c "lua MiniTest.run()" -c "qa"

helptags:
	nvim -c "helptags doc | q"

.deps:
	@mkdir -p .deps
	@if [ ! -d "$(MINI_DIR)/.git" ]; then \
		git clone --depth 1 "$(MINI_URL)" "$(MINI_DIR)"; \
	fi
