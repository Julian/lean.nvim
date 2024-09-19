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
---@field infoview? table infoview configuration
---@field lsp? table language server configuration
---@field progress_bars? table progress bar configuration
---@field stderr? table stderr window configuration

---@class lean.MergedConfig: lean.Config

---@class lean.abbreviations.Config
---@field enable? boolean whether to automatically enable expansion
---@field leader? string which key to use to trigger abbreviation expansion
---@field extra table<string, string> a table of extra abbreviations to enable

---@class lean.ft.Config
---@field nomodifiable string[] globs to prevent accidental modification

---@type lean.MergedConfig
local DEFAULTS = {
  mappings = false,

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
}

---@return lean.MergedConfig
return function()
  ---@type lean.Config
  vim.g.lean_config = vim.g.lean_config or {}
  return vim.tbl_deep_extend('keep', vim.g.lean_config, DEFAULTS)
end
