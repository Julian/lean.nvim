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
---@field infoview? lean.infoview.Config infoview configuration
---@field inlay_hint? lean.inlay_hint.Config inlay hint configuration
---@field lsp? table language server configuration
---@field progress_bars? table progress bar configuration
---@field stderr? table stderr window configuration
---
---Developer options.
---
---@field log? Log log any messages from lean.nvim's internals

---@class lean.MergedConfig: lean.Config
---@field ft lean.ft.MergedConfig filetype configuration
---@field goal_markers lean.goal_markers.Config characters to use for denoting goal markers
---@field infoview lean.infoview.MergedConfig infoview configuration
---@field inlay_hint lean.inlay_hint.Config inlay hint configuration
---@field log Log log any messages from lean.nvim's internals

---@class lean.abbreviations.Config
---@field enable? boolean whether to automatically enable expansion
---@field leader? string which key to use to trigger abbreviation expansion
---@field extra table<string, string> a table of extra abbreviations to enable

---@class lean.ft.Config
---@field nomodifiable string[] globs to prevent accidental modification

---@class lean.ft.MergedConfig: lean.ft.Config
---@field private should_modify fun(self, path:string): boolean

---@class lean.goal_markers.Config
---@field unsolved? string a character which will be placed on buffer lines where there is an unsolved goal
---@field accomplished? string a character which will be placed in the sign column of successful proofs

---@class lean.infoview.Config
---@field mappings? { [string]: ElementEvent }
---@field view_options? InfoviewViewOptions
---@field severity_markers? table<lsp.DiagnosticSeverity, string> characters to use for denoting diagnostic severity

---@class lean.infoview.MergedConfig
---@field view_options InfoviewViewOptions
---@field severity_markers table<lsp.DiagnosticSeverity, string> characters to use for denoting diagnostic severity

---Lean uses inlay hints to surface things like auto-implicits of a function.
---
---We enable them by default in Lean buffers, but they can be disabled if
---desired below. Note that they are not enabled globally in Neovim by default
---(as what exactly is shown in inlay hints can vary widely by language).
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
    ---@param path string
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
  },

  ---@type Log
  log = function() end,

  ---@type lean.infoview.Config
  infoview = {
    ---@type InfoviewViewOptions
    view_options = {
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

  ---@type lean.inlay_hint.Config
  inlay_hint = { enabled = true },
}

---Load our merged configuration merging user configuration with any defaults.
---@return lean.MergedConfig
return function()
  ---@type lean.Config
  vim.g.lean_config = vim.g.lean_config or {}
  return vim.tbl_deep_extend('keep', vim.g.lean_config, DEFAULTS)
end
