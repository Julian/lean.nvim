# `lean.nvim`'s Lua Packages

There are multiple Lua packages alongside this file which serve as API boundaries and which contain sets of related modules:

* `lean`: The main package containing all Lean-specific functionality.
  Other packages below were split off afterwards, so there still is plenty in this package which deserves splitting off.
  In particular it's likely we should better subdivide it into at least:

      - our TUI framework which is essentially entirely Lean agnostic
      - the actual RPC client for Lean (which implements Lean's RPC protocol)
      - our infoview implementation

  (This might not necessarily imply moving each of those out into new packages).
* `elan`: a Lua interface to `elan`, Lean's toolcahin version manager.
  It is in early stages.
* `std`: a collection of (completely Lean agnostic) Lua "extra standard library" code.
  Code here is stuff we wish were part of `neovim` (which is effectively Lua's real standard library in this case) or maintained in some community standard library.
  Aggresively removing things from it is acceptable if we stop using something or if we find a good implementation elsewhere.
* `telescope`: Lean related `telescope`: extensions for [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) which is the only fuzzy finding library we currently have additional support for, though we intend to change this to support additional ones (like `mini.picker`, `snacks.picker` or `fzy`)
  This should contain as little code as possible, as any real "logic" belongs in the `lean` package so that it can be used in this way with future additional fuzzy finders (so only telescope-specific code should appear).
