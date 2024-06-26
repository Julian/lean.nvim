packpath := justfile_directory() + "/packpath"
scripts := justfile_directory() + "/scripts"
tests := justfile_directory() + "/lua/tests"
demos := justfile_directory() + "/demos"

init_lua := scripts + "/minimal_init.lua"

# Run the lean.nvim test suite.
test: _rebuild-test-fixtures _clone-test-dependencies
    @just retest

# Run the test suite without rebuilding or recloning any dependencies.
retest *test_files=tests:
    nvim --headless -u {{ init_lua }} -c 'lua require("inanis").run{ specs = vim.split("{{ test_files }}", " "), minimal_init = "{{ init_lua }}", sequential = vim.env.TEST_SEQUENTIAL ~= nil }'

# Run an instance of neovim with the same minimal init used to run tests.
nvim setup_table='{}' *ARGS='':
    nvim -u {{ init_lua }} -c "lua require('lean').setup{{ setup_table }}" {{ ARGS }}

# Run an instance of neovim with a scratch buffer for interactive testing.
scratch *ARGS='':
    # still no idea why the extra :edit is required to get the LSP alive
    @just nvim '{ lsp = { enable = true }, mappings = true }' +edit {{ ARGS }} JustScratch.lean

# Coarsely profile how long the whole test suite takes to run.
profile-test *ARGS: _rebuild-test-fixtures _clone-test-dependencies
    hyperfine --warmup 2 {{ ARGS }} "just retest"

# Lint lean.nvim for style and typing issues.
lint:
    pre-commit run --all-files
    @echo
    {{ if `lua-language-server --version 2>&1 >/dev/null; echo $?` != "0" { error('lua-language-server not found') } else { "" } }}
    lua-language-server --check lua/lean --checklevel=Warning --configpath "{{ justfile_directory() }}/.luarc.json"

# Rebuild a demo from our VHS script.
demo:
    vhs {{ demos }}/basic.tape

# Update the versions of test fixtures used in CI.
bump-test-fixtures:
    cd {{ tests }}/fixtures/example-project/; gh api -H 'Accept: application/vnd.github.raw' '/repos/leanprover-community/Mathlib4/contents/lean-toolchain' >lean-toolchain && lake update
    git add {{ tests }}/fixtures/example-project/
    git commit -m "Bump the Lean versions in CI."

# Delete any previously cloned test dependencies.
_clean-test-dependencies:
    rm -rf '{{ packpath }}'
    mkdir '{{ packpath }}'

# Clone any neovim dependencies required for the plugin + test suite.
_clone-test-dependencies: _clean-test-dependencies
    for dependency in AndrewRadev/switch.vim andymass/vim-matchup Julian/inanis.nvim neovim/nvim-lspconfig nvim-lua/plenary.nvim tomtom/tcomment_vim; do \
        git clone --quiet --filter=blob:none "https://github.com/$dependency" "{{ packpath }}/$(basename $dependency)"; \
    done

# Rebuild some test fixtures used in the test suite.
_rebuild-test-fixtures:
    cd "{{ tests }}/fixtures/example-project/"; lake build
