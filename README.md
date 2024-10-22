<div align="center">
  <div>
    <div><img alt="lean.nvim" src="https://github.com/user-attachments/assets/727b689d-56f6-48e8-8fe5-a7a5d82b91c5" width="400px"/></div>
    <div><h1>lean.nvim</h1></div>
  </div>
  <table>
    <tr>
      <td>
        <strong><a href="https://neovim.io">Neovim</a> support for the <a href="https://lean-lang.org/">Lean Theorem Prover</a></strong>
      </td>
    </tr>
  </table>

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.10+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![MIT](https://img.shields.io/badge/MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
<a href="https://dotfyle.com/plugins/Julian/lean.nvim">
<img alt="dotfiles using lean.nvim" src="https://dotfyle.com/plugins/Julian/lean.nvim/shield?style=for-the-badge" />
</a>

</div>

https://github.com/Julian/lean.nvim/assets/329822/87f773a1-17b9-4938-b933-4f260f4228cd

## Installation

`lean.nvim` can be installed via your favorite plugin manager.
Here's an example doing so with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'Julian/lean.nvim',
  event = { 'BufReadPre *.lean', 'BufNewFile *.lean' },

  dependencies = {
    'neovim/nvim-lspconfig',
    'nvim-lua/plenary.nvim',
    -- you also will likely want nvim-cmp or some completion engine
  },

  -- see details below for full configuration options
  opts = {
    lsp = {},
    mappings = true,
  }
}
```

or with [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'Julian/lean.nvim'
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-lua/plenary.nvim'

" Optional Dependencies:

Plug 'hrsh7th/nvim-cmp'        " For LSP completion
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/vim-vsnip'       " For snippets
Plug 'andrewradev/switch.vim'  " For Lean switch support
Plug 'tomtom/tcomment_vim'     " For commenting motions
Plug 'nvim-telescope/telescope.nvim' " For Loogle search
```

`lean.nvim` supports the latest stable neovim release (currently `0.10.x`) as well as the latest nightly.
If you are on an earlier version of neovim, e.g. `0.9.5`, you can have your plugin manager install the [`nvim-0.9` tag](https://github.com/Julian/lean.nvim/releases/tag/nvim-0.9) until you upgrade.

## Features

- Abbreviation (unicode character) insertion (in insert mode & the command window accessible via `q/`)

- An infoview which can show persistent goal, term & tactic state, as well as interactive widget support (for most widgets renderable as text)

- Hover (preview) commands:

  - `:LeanGoal` for showing goal state in a preview window

  - `:LeanTermGoal` for showing term-mode type information in a preview window

- If [satellite.nvim](https://github.com/lewis6991/satellite.nvim) is present an extension is registered for showing progress information for the whole document.
  Otherwise, we show progress information in the sign column.

- [switch.vim](https://github.com/AndrewRadev/switch.vim/) base definitions for Lean
- If [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) is present, a `:Telescope loogle` command is available as a frontend for the [Loogle](https://loogle.lean-lang.org) JSON API.
- Simple snippets (in [VSCode-compatible format](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax), usable with e.g. [vim-vsnip](https://github.com/hrsh7th/vim-vsnip))
- Lean library search path access via `lean.current_search_path()`, suitable for use e.g. with [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim/) for live grepping.
  See the wiki for [a sample configuration](https://github.com/Julian/lean.nvim/wiki/Configuring-&-Extending#live-grep).

## Configuration & Usage

The short version -- if you followed the instructions above for `lazy.nvim`, you likely simply want `opts = { mappings = true }` to call `lean.setup` and enable its default key mappings.

This is all you need if you already have something registered to run on the `LspAttach` `autocmd` which defines any language server key mappings you like, e.g. if you use Neovim with any other language.
In particular your `LspAttach` handler should likely bind things like `vim.lsp.buf.code_action` (AKA "the lightbulb") to ensure that you have easy access to code actions in Lean buffers.
Lean (or really `Std`) uses code actions for replacing "Try this:" suggestions, which you will almost certainly want to be able to perform.

If you do not already have a preferred setup which includes LSP key mappings and (auto)completion, you may find the [fuller example here in the wiki](https://github.com/Julian/lean.nvim/wiki/Getting-Started-From-the-Ground-Up) helpful.

If you are using another plugin manager (such as `vim-plug`), after following the installation instructions, add the below to `~/.config/nvim/plugin/lean.lua` or an equivalent:

```lua
require('lean').setup{ mappings = true }
```

More detail on the full list of supported configuration options can be found below.

(If you find you can't modify your source files due to the nvim `E21` error, this might be due to lean.nvim's effort prevent users from accidentally shooting themselves in the foot by modifying the Lean standard library. See the definition of `nomodifiable` below.)

## Semantic Highlighting

Lean supports [semantic highlighting](https://leanprover.github.io/lean4/doc/semantic_highlighting.html), in which the Lean server itself will signal how to highlight terms and symbols within the editor using information available to it.

Note that even though neovim supports this highlighting, you still will want to map the semantic highlighting groups to your color scheme appropriately.
For a sample setup, see [the wiki](https://github.com/Julian/lean.nvim/wiki/Configuring-&-Extending#semantic-highlighting).

## Mappings

If you've set `mappings = true` in your configuration (or have called `lean.use_suggested_mappings()` explicitly), a number of keys will be mapped either within Lean source files or within Infoview windows:

### In Lean Files

The key binding `<LocalLeader>` below refers to a configurable prefix key within neovim.
You can check what this key is set to within neovim by running the command `:echo maplocalleader`.
An error like `E121: Undefined variable: maplocalleader` indicates that it may not be set to any key.
This can be configured by putting a line at the top of your `~/.config/nvim/init.lua` of the form `vim.g.maplocalleader = '  '` (in this example, mapping `<LocalLeader>` to hitting the space key twice).

| Key                  | Function                                                            |
| -------------------- | ------------------------------------------------------------------- |
| `<LocalLeader>i`     | toggle the infoview open or closed                                  |
| `<LocalLeader>p`     | pause the current infoview                                          |
| `<LocalLeader>x`     | place an infoview pin                                               |
| `<LocalLeader>c`     | clear all current infoview pins                                     |
| `<LocalLeader>dx`    | place an infoview diff pin                                          |
| `<LocalLeader>dc`    | clear current infoview diff pin                                     |
| `<LocalLeader>dd`    | toggle auto diff pin mode                                           |
| `<LocalLeader>dt`    | toggle auto diff pin mode without clearing diff pin                 |
| `<LocalLeader>v`     | interactively configure infoview view options                       |
| `<LocalLeader><Tab>` | jump into the infoview window associated with the current lean file |
| `<LocalLeader>\\`    | show what abbreviation produces the symbol under the cursor         |
| `<LocalLeader>r`     | Restart the Lean server for the current file.                       |

> [!TIP]
> See `:help <LocalLeader>` if you haven't previously interacted with the local leader key.
> Some nvim users remap this key to make it easier to reach, so you may want to consider what key that means for your own keyboard layout.
> My (Julian's) `<Leader>` is set to `<Space>`, and my `<LocalLeader>` to `<Space><Space>`, which may be a good choice for you if you have no other preference.

> [!TIP]
> If you are also looking for a way to restart the Lean server, you can use the `:LspRestart` command, or map it to a key of your choice. It will restart the language servers for the current buffer/file, so this also applies to other language servers you may be using.

### In Infoview Windows

| Key                  | Function                                                          |
| -------------------- | ----------------------------------------------------------------- |
| `<CR>`               | click a widget or interactive area of the infoview                |
| `K`                  | click a widget or interactive area of the infoview                |
| `<Tab>`              | jump into a tooltip (from a widget click)                         |
| `<Shift-Tab>`        | jump out of a tooltip and back to its parent                      |
| `<Esc>`              | clear all open tooltips                                           |
| `J`                  | jump into a tooltip (from a widget click)                         |
| `C`                  | clear all open tooltips                                           |
| `I`                  | mouse-enter what is under the cursor                              |
| `i`                  | mouse-leave what is under the cursor                              |
| `gd`                 | go-to-definition of what is under the cursor                      |
| `gD`                 | go-to-declaration of what is under the cursor                     |
| `gy`                 | go-to-type of what is under the cursor                            |
| `<LocalLeader><Tab>` | jump to the lean file associated with the current infoview window |

## Full Configuration & Settings Information

```lua
  require('lean').setup{
    -- Enable the Lean language server(s)?
    --
    -- false to disable, otherwise should be a table of options to pass to `leanls`
    --
    -- See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#leanls for details.
    -- In particular ensure you have followed instructions setting up a callback
    -- for `LspAttach` which sets your key bindings!
    lsp = {
      init_options = {
        -- See Lean.Lsp.InitializationOptions for details and further options.

        -- Time (in milliseconds) which must pass since latest edit until elaboration begins.
        -- Lower values may make editing feel faster at the cost of higher CPU usage.
        -- Note that lean.nvim changes the Lean default for this value!
        editDelay = 0,

        -- Whether to signal that widgets are supported.
        hasWidgets = true,
      }
    },

    ft = {
      -- A list of patterns which will be used to protect any matching
      -- Lean file paths from being accidentally modified (by marking the
      -- buffer as `nomodifiable`).
      nomodifiable = {
          -- by default, this list includes the Lean standard libraries,
          -- as well as files within dependency directories (e.g. `_target`)
          -- Set this to an empty table to disable.
      }
    },

    -- Abbreviation support
    abbreviations = {
      -- Enable expanding of unicode abbreviations?
      enable = true,
      -- additional abbreviations:
      extra = {
        -- Add a \wknight abbreviation to insert ♘
        --
        -- Note that the backslash is implied, and that you of
        -- course may also use a snippet engine directly to do
        -- this if so desired.
        wknight = '♘',
      },
      -- Change if you don't like the backslash
      -- (comma is a popular choice on French keyboards)
      leader = '\\',
    },

    -- Enable suggested mappings?
    --
    -- false by default, true to enable
    mappings = false,

    -- Infoview support
    infoview = {
      -- Automatically open an infoview on entering a Lean buffer?
      -- Should be a function that will be called anytime a new Lean file
      -- is opened. Return true to open an infoview, otherwise false.
      -- Setting this to `true` is the same as `function() return true end`,
      -- i.e. autoopen for any Lean file, or setting it to `false` is the
      -- same as `function() return false end`, i.e. never autoopen.
      autoopen = true,

      -- Set infoview windows' starting dimensions.
      -- Windows are opened horizontally or vertically depending on spacing.
      width = 50,
      height = 20,

      -- Put the infoview on the top or bottom when horizontal?
      -- top | bottom
      horizontal_position = "bottom",

      -- Always open the infoview window in a separate tabpage.
      -- Might be useful if you are using a screen reader and don't want too
      -- many dynamic updates in the terminal at the same time.
      -- Note that `height` and `width` will be ignored in this case.
      separate_tab = false,

      -- Show indicators for pin locations when entering an infoview window?
      -- always | never | auto (= only when there are multiple pins)
      indicators = "auto",
    },

    -- Progress bar support
    progress_bars = {
      -- Enable the progress bars?
      -- By default, this is `true` if satellite.nvim is not installed, otherwise
      -- it is turned off, as when satellite.nvim is present this information would
      -- be duplicated.
      enable = true,  -- see above for default
      -- What character should be used for the bars?
      character = '│',
      -- Use a different priority for the signs
      priority = 10,
    },

    -- Redirect Lean's stderr messages somehwere (to a buffer by default)
    stderr = {
      enable = true,
      -- height of the window
      height = 5,
      -- a callback which will be called with (multi-line) stderr output
      -- e.g., use:
      --   on_lines = function(lines) vim.notify(lines) end
      -- if you want to redirect stderr to `vim.notify`.
      -- The default implementation will redirect to a dedicated stderr
      -- window.
      on_lines = nil,
    },
  }
```

## Other Useful Plugins

Particularly if you're also a VSCode user, there may be other plugins you're interested in.
Below is a (hopelessly incomplete) list of a few:

- [actions-preview.nvim](https://github.com/aznhe21/actions-preview.nvim) for showing a preview of what a code action would change

- [nvim-lightbulb](https://github.com/kosayoda/nvim-lightbulb) for signalling when code actions are available

- [goto-preview](https://github.com/rmagatti/goto-preview) for peeking definitions (instead of jumping to them)

- [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) for showing LSP information in your status bar

## Contributing

Contributions are most welcome.
Feel free to send pull requests for anything you'd like to see, or open an issue if you'd like to discuss.

Running the tests can be done via [`just`](https://github.com/casey/just) using the adjacent [`justfile`](../justfile):

```sh
  just
```

which will execute against a minimal `init.lua` isolated from your own setup.

After running the test suite once, you can save some time re-cloning dependencies by instead now running:

```sh
  just retest
```

You can also run single test files by running:

```sh
  just retest lua/tests/ft_spec.lua
```

Some linting and style checking is done via [`pre-commit`](https://pre-commit.com/#install), which once installed (via the linked instructions) is run via:

```sh
  just lint
```

or on each commit automatically if you have run `pre-commit install` in your repository checkout.

You can also use

```sh
  just nvim '{ lsp = { enable = true }, mappings = true }'
```

to get a normal running neovim (again isolated from your own configuration), where the provided argument is a (Lua) table like one would pass to `lean.setup`.
Any further arguments will be passed to `nvim`.
