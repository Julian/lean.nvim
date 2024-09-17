packpath := justfile_directory() + "/packpath"
scripts := justfile_directory() + "/scripts"
doc := justfile_directory() + "/doc/lean.txt"
src := justfile_directory() + "/lua"
lean := src + "/lean"
spec := justfile_directory() + "/spec"
fixtures := spec + "/fixtures"
demos := justfile_directory() + "/demos"

init_lua := scripts + "/minimal_init.lua"

# Run the lean.nvim test suite.
test: _rebuild-test-fixtures _clone-test-dependencies
    @just retest

# Run the test suite without rebuilding or recloning any dependencies.
retest *test_files=spec:
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
    lua-language-server --check {{ lean }} --checklevel=Warning --configpath "{{ justfile_directory() }}/.luarc.json"
    {{ if `selene --version 2>&1 >/dev/null; echo $?` != "0" { error('selene not found') } else { "" } }}
    selene {{ src }}

# Rebuild a demo from our VHS script.
demo:
    cd {{ demos }}/project/ && lake build Mathlib.Analysis.SpecialFunctions.Pow.Real Mathlib.Data.Real.Irrational
    cd {{ justfile_directory() }}; vhs {{ demos }}/basic.tape

# Regenerate the vimdoc help text. Assumes you have already installed https://github.com/mrcjkb/vimcats.
docs:
    vimcats \
        {{ lean }}/init.lua \
        {{ lean }}/commands.lua \
        {{ lean }}/config.lua \
        {{ lean }}/infoview.lua \
        {{ lean }}/abbreviations.lua \
        {{ lean }}/loogle.lua \
        {{ lean }}/satellite.lua \
        {{ lean }}/lsp.lua \
        {{ lean }}/widgets.lua \
        {{ lean }}/health.lua \
        {{ lean }}/stderr.lua \
        {{ lean }}/sorry.lua \
        >{{ doc }}

# Update the versions of test fixtures used in CI.
bump-test-fixtures:
    gh api -H 'Accept: application/vnd.github.raw' '/repos/leanprover-community/Mathlib4/contents/lean-toolchain' | tee "{{ fixtures }}/example-project/lean-toolchain" "{{ demos }}/project/lean-toolchain"
    cd {{ fixtures }}/example-project/ && lake update
    cd {{ demos }}/project/ && MATHLIB_NO_CACHE_ON_UPDATE=1 lake update
    git add {{ justfile_directory() }}/**/lean-toolchain {{ justfile_directory() }}/**/lake-manifest.json
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
    cd "{{ fixtures }}/example-project/"; lake build
