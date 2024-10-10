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
---@field infoview? lean.infoview.Config infoview configuration
---@field lsp? table language server configuration
---@field progress_bars? table progress bar configuration
---@field stderr? table stderr window configuration

---@class lean.MergedConfig: lean.Config

---@class lean.abbreviations.Config
---@field enable? boolean whether to automatically enable expansion
---@field leader? string which key to use to trigger abbreviation expansion
---@field extra table<string, string> a table of extra abbreviations to enable

---@alias FilterHypothesis fun(hyp: InteractiveHypothesisBundle): boolean?

---@class lean.ft.Config
---@field nomodifiable string[] globs to prevent accidental modification
---@field private should_modify function(path): boolean

---@class lean.infoview.Config
---@field view_options? InfoviewViewOptions
---@field severity_markers? table<lsp.DiagnosticSeverity, string> characters to use for denoting diagnostic severity

---@type lean.MergedConfig
local DEFAULTS = {
  mappings = false,

  ---@type lean.abbreviations.Config
  abbreviations = {
    leader = '\\',
    extra = {},
  },

  ---@type lean.ft.Config
  ft = {
    nomodifiable = {
      '.*/src/lean/.*', -- Lean core library
    },

    ---Check whether a given path should be modifiable.
    ---@return boolean
    should_modify = function(self, path)
      path = path or vim.api.nvim_buf_get_name(0)
      return not vim.iter(self.nomodifiable):any(function(pattern)
        return path:match(pattern)
      end)
    end,
  },

  ---@type lean.infoview.Config
  infoview = {
    ---@type InfoviewViewOptions
    view_options = {
      show_types = true,
      show_instances = true,
      show_hidden_assumptions = true,
      show_let_values = true,
      reverse = false,
    },
    severity_markers = {
      'error:\n',
      'warning:\n',
      'information:\n',
      'hint:\n',
    },
  },
}

--- Load our merged configuration merging user configuration with any defaults.
---@return lean.MergedConfig
return function()
  ---@type lean.Config
  vim.g.lean_config = vim.g.lean_config or {}
  return vim.tbl_deep_extend('keep', vim.g.lean_config, DEFAULTS)
end
