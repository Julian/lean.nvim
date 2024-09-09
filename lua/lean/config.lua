---@class lean.Config
---@field mappings boolean whether to automatically enable key mappings
---@field ft? lean.ft.Config filetype configuration

---@class lean.MergedConfig: lean.Config

---@class lean.ft.Config
---@field nomodifiable string[] globs to prevent accidental modification

---@type lean.MergedConfig
local DEFAULTS = {
  mappings = false,

  ---@type lean.ft.Config
  ft = {
    nomodifiable = {
      '.*/src/lean/.*', -- Lean core library
    },

    ---Check whether a given path should be modifiable.
    ---@return boolean
    should_modify = function(self, path)
      path = path or vim.api.nvim_buf_get_name(0)
      return vim.iter(self.nomodifiable):any(function(pattern)
        return not path:match(pattern)
      end)
    end,
  },
}

---@return lean.MergedConfig
return function()
  ---@type lean.Config
  vim.g.lean_config = vim.g.lean_config or {}
  return vim.tbl_extend('keep', vim.g.lean_config, DEFAULTS)
end
