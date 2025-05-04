local Window = require 'std.nvim.window'

---A Neovim tab.
---@class Tab
---@field id integer The tab number
local Tab = {}
Tab.__index = Tab

---Bind to a Neovim tab.
---@param id? integer tab ID, defaulting to the current one
---@return Tab
function Tab:from_id(id)
  return setmetatable({ id = id or vim.api.nvim_get_current_buf() }, self)
end

---Bind to the current tab.
function Tab:current()
  return self:from_id(vim.api.nvim_get_current_tabpage())
end

---Return the windows present in the tab.
---@return Window[] windows
function Tab:windows()
  return vim
    .iter(vim.api.nvim_tabpage_list_wins(self.id))
    :map(function(win_id)
      return Window:from_id(win_id)
    end)
    :totable()
end

return Tab
