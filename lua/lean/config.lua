---@mod lean.config Configuration

---@brief [[
--- Configuration of lean.nvim.
---
--- Many of the types provided here are still being documented & typed.
---@brief ]]

---@class lean.Config
---@field mappings? boolean whether to automatically enable key mappings
---@field ft? lean.ft.Config filetype configuration
---@field abbreviations? lean.abbreviations.Config abbreviaton configuration
---@field goal_markers? lean.goal_markers.Config characters to use for denoting goal markers
---@field graphics? lean.graphics.Config terminal graphics configuration
---@field infoview? lean.infoview.Config infoview configuration
---@field inlay_hint? lean.inlay_hint.Config inlay hint configuration
---@field lsp? lean.lsp.Config language server configuration
---@field progress_bars? table progress bar configuration
---@field signs? lean.diagnostic.SignsConfig diagnostic sign column configuration
---@field stderr? table stderr window configuration
---@field on_imports_out_of_date? fun(integer):nil a callback called when imports are out of date in a buffer
---@field debug? lean.debug.Config developer options for debugging and introspection

---@class lean.MergedConfig: lean.Config
---@field ft lean.ft.MergedConfig filetype configuration
---@field goal_markers lean.goal_markers.Config characters to use for denoting goal markers
---@field graphics lean.graphics.Config terminal graphics configuration
---@field infoview lean.infoview.MergedConfig infoview configuration
---@field inlay_hint lean.inlay_hint.Config inlay hint configuration
---@field debug lean.debug.MergedConfig debugging and introspection configuration
---@field on_imports_out_of_date fun(integer):nil a callback called when imports are out of date in a buffer

---@class lean.abbreviations.Config
---@field enable? boolean whether to automatically enable expansion
---@field leader? string which key to use to trigger abbreviation expansion
---@field extra table<string, string> a table of extra abbreviations to enable

---@class lean.ft.Config
---@field nomodifiable string[] globs to prevent accidental modification

---@class lean.ft.MergedConfig: lean.ft.Config
---@field private should_modify fun(self, path?:string): boolean

---@class lean.goal_markers.Config
---@field unsolved? string a character which will be placed on buffer lines where there is an unsolved goal
---@field accomplished? string a character which will be placed in the sign column of successful proofs
---@field goals_accomplished? string a string to display in the infoview when the proof is successful
---@field no_goals? string a string to display in the infoview when there are no active goals

---@class lean.infoview.Config
---@field mappings? { [string]: ElementEvent }
---@field orientation? "auto"|"vertical"|"horizontal" what orientation to use for opened infoviews
---@field update_cooldown? integer milliseconds to throttle cursor-move updates (default 50, 0 to disable)
---@field view_options? InfoviewViewOptions
---@field severity_markers? table<lsp.DiagnosticSeverity, string> characters to use for denoting diagnostic severity

---@class lean.infoview.MergedConfig: lean.infoview.Config
---@field view_options InfoviewViewOptions
---@field severity_markers table<lsp.DiagnosticSeverity, string> characters to use for denoting diagnostic severity

---Configuration for the language server.
---@class lean.lsp.Config
---@field enable? boolean whether to enable the Lean language server (default true)
---@field enhanced_handlers? lean.lsp.EnhancedHandlers which LSP handlers to replace with enhanced versions

---lean.nvim replaces some default LSP handlers with enhanced versions.
---These can be individually disabled if they interfere with other plugins.
---@class lean.lsp.EnhancedHandlers
---@field hover? boolean replace the default hover with an interactive popup where subexpressions are clickable (default true)
---@field diagnostics? boolean replace the default diagnostics handler with one which filters silent diagnostics and renders multi-line signs (default true)

---Configuration for diagnostic signs in the sign column.
---
---When enabled, lean.nvim disables `vim.diagnostic`'s built-in sign
---rendering for the leanls LSP namespace (via
---`vim.diagnostic.config({ signs = false }, ns)`) and renders its own signs
---instead. Single-line diagnostics show the standard severity sign (E/W/I/H).
---Multi-line diagnostics whose `fullRange` extends past the clipped `range`
---show `┌│└` guide characters instead, making their full extent visible.
---
---If this interferes with another plugin's diagnostic sign handling, it can
---be disabled, which restores `vim.diagnostic`'s default sign behavior.
---@class lean.diagnostic.SignsConfig
---@field enabled? boolean whether to render our own diagnostic signs (default true)

---Lean uses inlay hints to surface things like auto-implicits of a function.
---
---We enable them by default in Lean buffers, but they can be disabled if
---desired below. Note that they are not enabled globally in Neovim by default
---(as what exactly is shown in inlay hints can vary widely by language).

---Terminal graphics configuration.
---
---When enabled (the default), lean.nvim renders rich content like SVGs via the
---Kitty graphics protocol in terminals that support it. Disable to suppress
---all terminal graphics output.
---@class lean.graphics.Config
---@field enabled? boolean whether to enable terminal graphics (default true)

---Developer options for debugging lean.nvim internals.
---
---`log` receives all internal log messages (connection events, RPC errors,
---etc.) and defaults to a no-op. Set `rpc_history` to a positive number to
---keep that many RPC request records per session, queryable via
---`rpc.sessions()` and `rpc.history()`.
---@class lean.debug.Config
---@field log? Log a handler called with (level, data) for internal log messages
---@field rpc_history? integer enable RPC request history with this many entries (0 or nil to disable)

---@class lean.debug.MergedConfig: lean.debug.Config
---@field log Log a handler called with (level, data) for internal log messages

---@class lean.inlay_hint.Config
---@field enabled? boolean whether to automatically enable inlay hints

---@type lean.MergedConfig
local DEFAULTS = {
  mappings = false,

  ---@type lean.abbreviations.Config
  abbreviations = {
    leader = '\\',
    extra = {},
  },

  ---@type lean.ft.MergedConfig
  ft = {
    nomodifiable = {
      '.*/src/lean/.*', -- Lean core library
      '.*/.elan/.*', -- elan toolchains
      '.*/.lake/.*', -- project dependencies
    },

    ---Check whether a given path should be modifiable.
    ---@param self lean.ft.MergedConfig
    ---@param path? string
    ---@return boolean
    should_modify = function(self, path)
      path = path or vim.api.nvim_buf_get_name(0)
      return not vim.iter(self.nomodifiable):any(function(pattern)
        return path:match(pattern)
      end)
    end,
  },

  ---@type lean.goal_markers.Config
  goal_markers = {
    unsolved = ' ⚒ ',
    accomplished = '🎉',
    goals_accomplished = 'Goals accomplished 🎉',
    no_goals = 'No goals.',
  },

  ---@type lean.lsp.Config
  lsp = {
    enhanced_handlers = {
      hover = true,
      diagnostics = true,
    },
  },

  ---@type lean.graphics.Config
  graphics = { enabled = true },

  ---@type lean.debug.MergedConfig
  debug = {
    log = function() end,
    rpc_history = 0,
  },

  ---@type lean.infoview.Config
  infoview = {
    ---@type InfoviewViewOptions
    view_options = {
      use_widgets = true,
      show_types = true,
      show_instances = true,
      show_hidden_assumptions = true,
      show_let_values = true,
      show_term_goals = true,
      reverse = false,
    },
    severity_markers = {
      'error:\n',
      'warning:\n',
      'information:\n',
      'hint:\n',
    },
  },

  ---@param bufnr integer
  on_imports_out_of_date = function(bufnr)
    vim.ui.select({ 'restart', 'not now' }, {
      prompt = 'Imports are out of date and must be rebuilt for this file.',
    }, function(choice)
      if choice == 'restart' then
        require('lean.lsp').restart_file(bufnr)
      end
    end)
  end,

  ---@type lean.inlay_hint.Config
  inlay_hint = { enabled = true },

  ---@type lean.diagnostic.SignsConfig
  signs = { enabled = true },
}

---Load our merged configuration merging user configuration with any defaults.
---@return lean.MergedConfig
return function()
  ---@type lean.Config
  vim.g.lean_config = vim.g.lean_config or {}
  return vim.tbl_deep_extend('keep', vim.g.lean_config, DEFAULTS)
end
