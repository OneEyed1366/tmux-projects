.PHONY: help install uninstall test test-bash test-lua lint lint-bash lint-lua clean

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
SCRIPT := bin/tmux-sessionizer
LIB    := lib/tmux-sessionizer.sh
TESTS_BASH := $(wildcard tests/bash/*.bats)
TESTS_LUA  := $(wildcard tests/lua/*_spec.lua)

help:
	@echo "tmux-projects make targets:"
	@echo "  install        - copy $(SCRIPT) to $(BINDIR) and $(LIB) to $(LIBDIR)"
	@echo "  uninstall      - remove both installed files"
	@echo "  test           - run bash + lua tests"
	@echo "  test-bash      - run bats tests (tests/bash/*.bats)"
	@echo "  test-lua       - run mini.test (tests/lua/*_spec.lua)"
	@echo "  lint           - run shellcheck + stylua"
	@echo "  lint-bash      - run shellcheck on $(SCRIPT), lib/, install.sh, uninstall.sh"
	@echo "  lint-lua       - run stylua --check on nvim-plugin/"
	@echo "  clean          - remove test artifacts"
	@echo
	@echo "Variables:"
	@echo "  PREFIX=DIR     - install prefix (default: \$$(HOME)/.local)"
	@echo "  BINDIR=DIR     - install bin dir (default: \$$(PREFIX)/bin)"
	@echo "  LIBDIR=DIR     - install lib dir (default: \$$(PREFIX)/lib)"

install:
	install -d $(BINDIR) $(LIBDIR)
	install -m 0755 $(SCRIPT) $(BINDIR)/tmux-sessionizer
	install -m 0644 $(LIB) $(LIBDIR)/tmux-sessionizer.sh
	@echo "Installed: $(BINDIR)/tmux-sessionizer"
	@echo "Installed: $(LIBDIR)/tmux-sessionizer.sh"

uninstall:
	rm -f $(BINDIR)/tmux-sessionizer $(LIBDIR)/tmux-sessionizer.sh
	@echo "Removed $(BINDIR)/tmux-sessionizer"
	@echo "Removed $(LIBDIR)/tmux-sessionizer.sh"

test: test-bash test-lua

test-bash:
	@if command -v bats >/dev/null 2>&1; then \
		bats $(TESTS_BASH); \
	else \
		echo "bats not found. Install: brew install bats-core"; \
		exit 1; \
	fi

test-lua:
	@if command -v nvim >/dev/null 2>&1; then \
		nvim --headless -u tests/lua/minimal_init.lua \
			-c "lua MiniTest.run({ collect = { find_files = function() return vim.fn.globpath('tests/lua', '*_spec.lua', true, true) end } })" \
			-c "qa!"; \
	else \
		echo "nvim not found"; \
		exit 1; \
	fi

lint: lint-bash lint-lua

lint-bash:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SCRIPT) $(LIB) install.sh uninstall.sh; \
	else \
		echo "shellcheck not found. Install: brew install shellcheck"; \
		exit 1; \
	fi

lint-lua:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check nvim-plugin/; \
	else \
		echo "stylua not found. Install: brew install stylua"; \
		exit 1; \
	fi

clean:
	rm -rf .nvim-test/ /tmp/tmux-sessionizer-test/ bats-tmp/ /tmp/extra-test.txt
