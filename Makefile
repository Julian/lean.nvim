.PHONY: docgen nvim lint test

nvim:
	nvim --noplugin -u scripts/minimal_init.lua $(ARGS)

docgen:
	nvim --headless --noplugin -u scripts/minimal_init.lua -c "luafile ./scripts/gendocs.lua" -c "qa"

test:
	nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedDirectory lua/tests/ { minimal_init = './scripts/minimal_init.lua' }"

lint:
	pre-commit run --all-files
