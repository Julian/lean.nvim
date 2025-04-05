---@brief [[
--- Support for "selectable locations" and its statefulness.
---@brief ]]

---@tag lean.infoview.locations

local inductive = require 'std.inductive'

---The last locations for a given URI.
---
---Used to preserve selected locations if the cursor moves into and out of a
---window without really "moving" within the window.
---@type table<string, { [1]: lsp.Position, [2]: Locations }>
local last_locations_at = {}

---Locations within the goal state which have been selected ("shift+click"ed).
---@class Locations
---@field selected GoalsLocation[] the currently selected locations
local Locations = {}
Locations.__index = Locations

---Create a new Locations object with nothing selected.
function Locations:new(obj)
  obj = obj or {}
  obj.selected = {}
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

  local locations = Locations:new()
  last_locations_at[params.textDocument.uri] = { params.position, locations }
  return locations
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
end

---@param pos SubexprPos
function Locations:toggle_subexpr_selection(pos)
  -- TODO: LocationContext state (subexprTemplate) from VSCode
end

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
      return self(self[1], pos)
    end,
  },
  hypValue = {
    ---@param self GoalLocationHypValue
    ---@param pos SubexprPos
    with_subexpr_pos = function(self, pos)
      return self(self[1], pos)
    end,
  },
  target = {
    ---@param self GoalLocationTarget
    ---@param pos SubexprPos
    with_subexpr_pos = function(self, pos)
      return self(pos)
    end,
  },
})

return Locations
