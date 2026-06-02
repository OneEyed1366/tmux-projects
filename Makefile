.PHONY: install uninstall test test-bash test-lua lint lint-bash lint-lua clean help

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
SCRIPT := bin/tmux-sessionizer

help:
	@echo "tmux-projects make targets:"
	@echo "  install    - copy $(SCRIPT) to $(BINDIR)"
	@echo "  uninstall  - remove $(BINDIR)/tmux-sessionizer"
	@echo "  test       - run bash + lua tests"
	@echo "  test-bash  - run bats tests"
	@echo "  test-lua   - run mini.test"
	@echo "  lint       - run shellcheck + stylua"
	@echo "  lint-bash  - run shellcheck on $(SCRIPT)"
	@echo "  lint-lua   - run stylua --check on nvim-plugin/"
	@echo "  clean      - remove test artifacts"

install:
	install -d $(BINDIR)
	install -m 0755 $(SCRIPT) $(BINDIR)/tmux-sessionizer
	@echo "Installed to $(BINDIR)/tmux-sessionizer"

uninstall:
	rm -f $(BINDIR)/tmux-sessionizer
	@echo "Removed $(BINDIR)/tmux-sessionizer"

test: test-bash test-lua

test-bash:
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/bash/; \
	else \
		echo "bats not found. Install: brew install bats-core"; \
		exit 1; \
	fi

test-lua:
	@if command -v nvim >/dev/null 2>&1; then \
		nvim --headless -u tests/lua/minimal_init.lua \
			-c "lua MiniTest.run({ collect = { find_files = function() return vim.fn.globpath('tests/lua', '**/*_spec.lua', true, true) end } })" \
			-c "qa!" 2>&1; \
	else \
		echo "nvim not found"; \
		exit 1; \
	fi

lint: lint-bash lint-lua

lint-bash:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SCRIPT); \
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
	rm -rf .nvim-test/ /tmp/tmux-sessionizer-test/ bats-tmp/
