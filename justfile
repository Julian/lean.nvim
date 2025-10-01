packpath := justfile_directory() / "packpath"
scripts := justfile_directory() / "scripts"
doc := justfile_directory() / "doc"
devcontainer := justfile_directory() / ".devcontainer/lazyvim"
src := justfile_directory() / "lua"
lean := src / "lean"
spec := justfile_directory() / "spec"
fixture_projects := spec / "fixtures/projects"
demos := justfile_directory() / "demos"

init_lua := scripts / "minimal_init.lua"
clean_config := justfile_directory() / ".test-config"

# Run the lean.nvim test suite.
[group('testing')]
test: _rebuild-test-fixtures _clone-test-dependencies
    @just retest

# Run the test suite without rebuilding or recloning any dependencies.
[group('testing')]
retest *test_files=spec:
    XDG_CONFIG_HOME="{{ clean_config }}" nvim --headless --clean -u {{ init_lua }} -c 'lua require("inanis").run{ specs = vim.split("{{ test_files }}", " "), minimal_init = "{{ init_lua }}", sequential = vim.env.TEST_SEQUENTIAL ~= nil }'

# Run an instance of neovim with the same minimal init used to run tests.
[group('dev')]
nvim *ARGS='':
    XDG_CONFIG_HOME="{{ clean_config }}" nvim --clean -u {{ init_lua }} -c "lua require('lean').setup(vim.g.lean_config)" {{ ARGS }}

ocibuild := if os() == "macos"  { "container" } else { "podman" }

# Run an instance of the `devcontainer` which uses LazyVim.
[group('dev')]
devcontainer ocibuild=ocibuild tag="lazylean" *ARGS='':
    {{ ocibuild }} build -f  {{ devcontainer }}/Dockerfile -t {{ tag }} {{ devcontainer }}
    {{ ocibuild }} run --rm -it {{ tag }} {{ ARGS }}

# Run an instance of neovim with a scratch buffer for interactive testing.
[group('dev')]
scratch *ARGS='':
    # still no idea why the extra :edit is required to get the LSP alive
    @just nvim +edit +'setlocal\ buftype=nofile' {{ ARGS }} JustScratch.lean

# Coarsely profile how long the whole test suite takes to run.
[group('testing')]
profile-test *ARGS: _rebuild-test-fixtures _clone-test-dependencies
    hyperfine --warmup 2 {{ ARGS }} "just retest"

# Lint lean.nvim for style and typing issues.
[group('dev')]
lint:
    pre-commit run --all-files
    @echo
    {{ if `lua-language-server --version 2>&1 >/dev/null; echo $?` != "0" { error('lua-language-server not found') } else { "" } }}
    # Commented out as luals is impossible to configure for finding Neovim's own type declarations
    # lua-language-server --check {{ lean }} --checklevel=Warning --configpath "{{ justfile_directory() }}/.luarc.json"
    {{ if `selene --version 2>&1 >/dev/null; echo $?` != "0" { error('selene not found') } else { "" } }}
    selene {{ src }}

# Rebuild a demo from our VHS script. Requires `vhs` to be installed.
demo:
    cd {{ demos }}/project/ && lake build Mathlib.Analysis.SpecialFunctions.Pow.Real Mathlib.Data.Real.Irrational
    cd {{ justfile_directory() }}; vhs {{ demos }}/basic.tape

# Regenerate the vimdoc help text. Assumes you have already installed https://github.com/mrcjkb/vimcats.
[group('dev')]
docs:
    vimcats \
        {{ lean }}/init.lua \
        {{ lean }}/commands.lua \
        {{ lean }}/config.lua \
        {{ lean }}/abbreviations.lua \
        {{ lean }}/widgets.lua \
        {{ lean }}/health.lua \
        {{ lean }}/infoview.lua \
        {{ lean }}/goals.lua \
        {{ lean }}/stderr.lua \
        {{ lean }}/widgets.lua \
        {{ lean }}/lsp.lua \
        {{ lean }}/diagnostic.lua \
        >{{ doc }}/lean.txt
    vimcats \
        {{ src }}/elan/init.lua \
        {{ src }}/elan/toolchain.lua \
        >{{ doc }}/elan.txt

    nvim --headless --clean -u {{ init_lua }} -c 'helptags {{ doc }}' -c 'quit'

export MATHLIB_NO_CACHE_ON_UPDATE := "1"

# Update the version of Lean we use to the one currently used by Mathlib, along with any Lean dependencies.
[group('testing')]
bump-test-fixtures:
    gh api -H 'Accept: application/vnd.github.raw' '/repos/leanprover-community/Mathlib4/contents/lean-toolchain' | tee "{{ fixture_projects }}"/*/lean-toolchain "{{ demos }}/project/lean-toolchain"
    for each in "{{ fixture_projects }}"/*; do cd "$each" && lake update; done
    cd {{ demos }}/project/ && lake update
    git add {{ justfile_directory() }}/**/lean-toolchain {{ justfile_directory() }}/**/lake-manifest.json
    git commit -m "Bump the Lean versions in CI."

# Delete any previously cloned dependencies.
_clean-dependencies:
    rm -rf '{{ packpath }}'
    mkdir '{{ packpath }}'

# Clone any neovim dependencies required for the plugin.
_clone-dependencies: _clean-dependencies
    for dependency in AndrewRadev/switch.vim andymass/vim-matchup nvim-lua/plenary.nvim tomtom/tcomment_vim lewis6991/satellite.nvim; do \
        git clone --quiet --filter=blob:none "https://github.com/$dependency" "{{ packpath }}/$(basename $dependency)"; \
    done

# Clone any neovim dependencies required for the test suite.
_clone-test-dependencies: _clone-dependencies
    for dependency in Julian/inanis.nvim; do \
        git clone --quiet --filter=blob:none "https://github.com/$dependency" "{{ packpath }}/$(basename $dependency)"; \
    done

# Rebuild some test fixtures used in the test suite.
_rebuild-test-fixtures:
    cd "{{ fixture_projects}}/Example/" && lake build
    cd "{{ fixture_projects }}/WithWidgets/" && lake build ProofWidgets Mathlib.Tactic.Widget.Conv Mathlib.Tactic.Widget.InteractiveUnfold
