# `lean.nvim`'s Lua Packages

There are multiple Lua packages alongside this file which serve as API boundaries and which contain sets of related modules:

* `lean`: The main package containing all Lean-specific functionality.
  Other packages below were split off afterwards, so there still is plenty in this package which deserves splitting off.
  In particular it's likely we should better subdivide it into at least:

      - the actual RPC client for Lean (which implements Lean's RPC protocol)
      - our infoview implementation

  (This might not necessarily imply moving each of those out into new packages).
* `lean.widgets`: A namespace for Lua reimplementations of Lean user widgets.
  For example, the `Lean.Meta.Tactic.TryThis.tryThisWidget` lives at `lean.widgets.Lean.Meta.Tactic.TryThis.trythisWidget`, a Lua module which implements its behavior.
* `tui`: A package for our homegrown (ugh) TUI framework.
  Note that most of the guts here still lives in `lean/tui.lua` as it needs a bit of tearing away from Lean-specific functionality to truly be self contained, which we want to do but will likely do incrementally.
* `elan`: a Lua interface to `elan`, Lean's toolchain version manager.
  It is in early stages.
* `proofwidgets`: a Lua reimplementation of portions of the [ProofWidgets4](https://github.com/leanprover-community/ProofWidgets4) library and its widgets
* `std`: a collection of (again Lean agnostic) "Lua standard library" code.
  Code here is stuff we wish were part of `neovim` (which is effectively Lua's real standard library in this case) or maintained in some community standard library.
  Aggressively removing things from it is acceptable if we stop using something or if we find a good implementation elsewhere.
* `telescope`: Lean related `telescope`: extensions for [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) which is the only fuzzy finding library we currently have additional support for, though we intend to change this to support additional ones (like `mini.picker`, `snacks.picker` or `fzy`)
  This should contain as little code as possible, as any real "logic" belongs in the `lean` package so that it can be used in this way with future additional fuzzy finders (so only telescope-specific code should appear).
