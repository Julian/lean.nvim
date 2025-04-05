---@brief [[
--- Support for "selectable locations" and its statefulness.
---@brief ]]

---@tag lean.infoview.locations

local inductive = require 'std.inductive'

---@alias GoalLocationHyp FVarId
---@alias GoalLocationHypType {[1]: FVarId, [2]: SubexprPos}
---@alias GoalLocationHypValue {[1]: FVarId, [2]: SubexprPos}
---@alias GoalLocationTarget SubexprPos

local GoalLocation = inductive('GoalLocation', {
  hyp = {
    ---@param self GoalLocationHyp
    with_subexpr_pos = function(self)
      return self
    end,
  },
  hypType = {
    ---@param self GoalLocationHypType
    ---@param pos SubexprPos
    with_subexpr_pos = function(self, pos)
      return self { self[1][1], pos }
    end,
  },
  hypValue = {
    ---@param self GoalLocationHypValue
    ---@param pos SubexprPos
    with_subexpr_pos = function(self, pos)
      return self { self[1][1], pos }
    end,
  },
  target = {
    ---@param self GoalLocationTarget
    ---@param pos SubexprPos
    with_subexpr_pos = function(self, pos)
      return self { pos }
    end,
  },
})

---The last locations for a given URI.
---
---Used to preserve selected locations if the cursor moves into and out of a
---window without really "moving" within the window.
---@type table<string, { [1]: lsp.Position, [2]: Locations }>
local last_locations_at = {}

---Locations within the goal state which have been selected ("shift+click"ed).
---@class Locations
---@field selected GoalsLocation[] the currently selected locations
---@field private subexpr_template? GoalsLocation a template used for any subexpression selection
local Locations = {}
Locations.__index = Locations

---Create a new Locations object.
function Locations:new(obj)
  obj = vim.tbl_extend('keep', obj or {}, { selected = {} })
  return setmetatable(obj, self)
end

---Return Locations for a given position.
---
---If the cursor hasn't moved since we last asked for locations, retrieves the
---last selected locations.
---
---Otherwise, returns a new empty set of selected locations.
function Locations.at(params)
  local last = last_locations_at[params.textDocument.uri]
  if last and vim.deep_equal(last[1], params.position) then
    return last[2]
  end

  local locations = Locations:new {}
  last_locations_at[params.textDocument.uri] = { params.position, locations }
  return locations
end

---A Locations object which represents those within the given "template" location.
---@param location GoalsLocation
---@return Locations locations_in
function Locations:in_template(location)
  return Locations:new { selected = self.selected, subexpr_template = location }
end

---Create a new Locations object with nothing selected.

---Toggle whether the given location is selected.
---@param loc GoalsLocation
function Locations:toggle_selection(loc)
  local previous = self.selected
  self.selected = vim
    .iter(self.selected)
    :filter(function(each)
      return not vim.deep_equal(each, loc)
    end)
    :totable()
  if #self.selected == #previous then
    table.insert(self.selected, loc)
  end
  local infoview = require('lean.infoview').get_current_infoview()
  local cursor = vim.api.nvim_win_get_cursor(0)
  if infoview then
    vim.api.nvim_win_call(infoview.info.last_window, function()
      infoview:__update()
    end)
    vim.api.nvim_win_set_cursor(0, cursor)
  end
end

---@param pos SubexprPos
function Locations:toggle_subexpr_selection(pos)
  assert(self.subexpr_template, 'No subexpr template set.')
  ---@type GoalsLocation
  local location = { -- FIXME
    mvarId = self.subexpr_template.mvarId,
    loc = GoalLocation(self.subexpr_template.loc):with_subexpr_pos(pos):serialize(),
  }
  self:toggle_selection(location)
end

return Locations
