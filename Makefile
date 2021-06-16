.PHONY: docgen nvim lint test

nvim_test = nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedDirectory lua/tests/$(1) { minimal_init = './scripts/minimal_init.lua' }"

nvim:
	nvim --noplugin -u scripts/minimal_init.lua $(ARGS)

docgen:
	nvim --headless --noplugin -u scripts/minimal_init.lua -c "luafile ./scripts/gendocs.lua" -c "qa"

test:
	$(call nvim_test,normal)
	$(call nvim_test,sorry)
	$(call nvim_test,trythis)
	$(call nvim_test,lsp/infoview)
	$(call nvim_test,lsp/lsp)

lint:
	pre-commit run --all-files
