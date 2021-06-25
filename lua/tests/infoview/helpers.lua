local assert = require('luassert')
local infoview = require('lean.infoview')

local ihelpers = {}

ihelpers.get_num_wins = function() return #vim.api.nvim_list_wins() end
local function open_state(state)
  if state.mod then return infoview.is_open() and not infoview.is_closed() end
  return infoview.is_open() or not infoview.is_closed()
end

assert:register("assertion", "open_state", open_state)
return ihelpers
