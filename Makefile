.PHONY: docgen nvim lint test _test

SETUP_TABLE="{}"
SETUP = "lua require'lean'.setup$(SETUP_TABLE)"

nvim:
	nvim --noplugin -u scripts/minimal_init.lua -c $(SETUP) $(ARGS)


docgen:
	nvim --headless --noplugin -u scripts/minimal_init.lua -c "luafile ./scripts/gendocs.lua" -c "qa"

build-test-fixtures:
	if [ -x "$$(command -v leanpkg)" ]; then \
		cd ./lua/tests/fixtures/example-lean3-project/ && leanpkg build; \
	fi
	cd ./lua/tests/fixtures/example-lean4-project/ && lake build

bump-test-fixtures:
	cd ./lua/tests/fixtures/example-lean3-project/ && leanproject up
	gh api -H 'Accept: application/vnd.github.raw' '/repos/leanprover-community/Mathlib4/contents/lean-toolchain' >./lua/tests/fixtures/example-lean4-project/lean-toolchain
	git add --all
	git commit -m "Bump the Lean versions in CI."

clean-deps:
	rm -rf packpath/

clone-deps: clean-deps
	mkdir packpath && cd packpath && \
	git clone --filter=blob:none https://github.com/AndrewRadev/switch.vim && \
	git clone --filter=blob:none https://github.com/Julian/inanis.nvim && \
	git clone --filter=blob:none https://github.com/neovim/nvim-lspconfig && \
	git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim && \
	git clone --filter=blob:none https://github.com/tomtom/tcomment_vim

test: build-test-fixtures clone-deps
	nvim --headless -u ./scripts/minimal_init.lua -l ./scripts/run_tests.lua

_test:
	nvim --headless -u ./scripts/minimal_init.lua -l ./scripts/run_tests.lua

profile-test: build-test-fixtures
	hyperfine --warmup 2 $(ARGS) "$(MAKE) _test"

coverage:
	$(MAKE) LEAN_NVIM_COVERAGE=1 test
	luacov
	cat luacov.report.out

install-luacov:
	luarocks --lua-version 5.1 install --tree luapath/ luacov
	@echo Run 'make coverage' now to enable coverage collection.

lint:
	pre-commit run --all-files
	if [ -x $$(command -v lua-language-server) ]; then \
		lua-language-server --check lua/lean --checklevel=Warning --configpath $(PWD)/.luarc.json; \
	fi
