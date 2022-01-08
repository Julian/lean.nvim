.PHONY: docgen nvim lint test _test

SETUP_TABLE="{}"
SETUP = "lua require'lean'.setup$(SETUP_TABLE)"

nvim:
	nvim --noplugin -u scripts/minimal_init.lua -c $(SETUP) $(ARGS)

docgen:
	nvim --headless --noplugin -u scripts/minimal_init.lua -c "luafile ./scripts/gendocs.lua" -c "qa"

build-test-fixtures:
	cd ./lua/tests/fixtures/example-lean3-project/ && leanpkg build
	cd ./lua/tests/fixtures/example-lean4-project/ && lake build

test: build-test-fixtures
	./lua/tests/scripts/run_tests.sh

_test:
	./lua/tests/scripts/run_tests.sh

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
