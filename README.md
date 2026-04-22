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
[![Neovim](https://img.shields.io/badge/Neovim%200.11+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![MIT](https://img.shields.io/badge/MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
<a href="https://dotfyle.com/plugins/Julian/lean.nvim">
<img alt="dotfiles using lean.nvim" src="https://dotfyle.com/plugins/Julian/lean.nvim/shield?style=for-the-badge" />
</a>

</div>

https://github.com/user-attachments/assets/d17554ae-bcce-4f73-ac34-38ae556caf45

## Installation

If you are using neovim 0.12 or later, you can install and configure `lean.nvim` using

```lua
vim.pack.add { "https://github.com/Julian/lean.nvim" }

require("lean").setup { mappings = true }
```

(see [the manual](https://github.com/Julian/lean.nvim/wiki/The-lean.nvim-Manual#key-mappings) for information about the `{ mappings = true }` part).

If you are using an older neovim, or do not wish to use `vim.pack`, `lean.nvim` can be installed via your favorite plugin manager.
Here's an example doing so with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'Julian/lean.nvim',
  event = { 'BufReadPre *.lean', 'BufNewFile *.lean' },

  dependencies = {
    -- optional dependencies:

    -- 'nvim-telescope/telescope.nvim', -- for Lean-specific pickers
    -- 'andymass/vim-matchup',          -- for enhanced % motion behavior
    -- 'andrewradev/switch.vim',        -- for switch support
    -- 'tomtom/tcomment_vim',           -- for commenting
  },

  ---@type lean.Config
  opts = { -- see the manual for full configuration options
    mappings = true,
  }
}
```

`lean.nvim` supports the latest stable neovim release (currently `0.12.x`) as well as the latest nightly.
If you are on an earlier version of neovim, e.g. `0.10.x`, you can have your plugin manager install the [`nvim-0.10` tag](https://github.com/Julian/lean.nvim/releases/tag/nvim-0.10) until you upgrade.

### Optional: Terminal Graphics

In terminals that support the [Kitty graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/) (Kitty, WezTerm, Ghostty, etc.), `lean.nvim` can render images and SVGs from ProofWidgets inline in the infoview.

SVG rendering requires [resvg](https://github.com/RazrFalcon/resvg) (`brew install resvg` or `cargo install resvg`).
Raster images (`<img>` tags with data URIs) work without any extra dependencies.

To disable all terminal graphics, pass `graphics = { enabled = false }` in your setup options.

## Sponsors

A portion of `lean.nvim`'s development is graciously sponsored by the [Lean FRO](https://lean-fro.org/).
It is undoubtedly the case that `lean.nvim` would not be as featureful without this support, for which we owe sincere thanks.

## Features

- Abbreviation (unicode character) insertion (in insert mode & the command window accessible via `q/`)

- An infoview which can show persistent goal, term & tactic state, as well as interactive widget support (for most widgets renderable as text)

- [User commands](https://github.com/Julian/lean.nvim/wiki/The-lean.nvim-Manual#commands) for interacting with infoviews, goals, diagnostics, and the Lean server (e.g. `:LeanGoal`, `:LeanInfoviewToggle`, `:LeanRestartFile`)

- File progress information for visible lines in the sign column.
  If [satellite.nvim](https://github.com/lewis6991/satellite.nvim) is present, a satellite extension is registered for showing progress information for the whole document within its floating window.

- [vim-matchup](https://github.com/andymass/vim-matchup) definitions for Lean
- [switch.vim](https://github.com/AndrewRadev/switch.vim/) base definitions for Lean
- If [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) is present, a `:Telescope loogle` command is available as a frontend for the [Loogle](https://loogle.lean-lang.org) JSON API.
- [Semantic highlighting](https://leanprover.github.io/lean4/doc/semantic_highlighting.html) support -- see the [manual](https://github.com/Julian/lean.nvim/wiki/The-lean.nvim-Manual#syntax-highlighting) for full details and the [wiki](https://github.com/Julian/lean.nvim/wiki/Configuring-&-Extending#semantic-highlighting) for a sample color scheme setup
- Simple snippets (in [VSCode-compatible format](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax), usable with e.g. [vim-vsnip](https://github.com/hrsh7th/vim-vsnip))
- Lean library search path access via `lean.current_search_path()`, which you might find useful as a set of paths to grep (or live grep) within
  See the wiki for [a sample configuration](https://github.com/Julian/lean.nvim/wiki/Configuring-&-Extending#live-grep).

## Configuration & Usage

For detail on the full list of supported configuration options, key mappings, and commands, see [the manual](https://github.com/Julian/lean.nvim/wiki/The-lean.nvim-Manual).

## Other Useful Plugins

Particularly if you're also a VSCode user, there may be other plugins you're interested in.
Below is a (hopelessly incomplete) list of a few:

- [nvim-lightbulb](https://github.com/kosayoda/nvim-lightbulb) for signalling when code actions are available

- [goto-preview](https://github.com/rmagatti/goto-preview) for peeking definitions (instead of jumping to them)

- [neominimap.nvim](https://github.com/Isrothy/neominimap.nvim) if you really like minimaps

## Contributing

Contributions are most welcome.
Feel free to send pull requests for anything you'd like to see, or open an issue if you'd like to discuss.
See [CONTRIBUTING.md](CONTRIBUTING.md) for details on running tests, linting and testing.
