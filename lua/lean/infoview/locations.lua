---@brief [[
--- Support for "selectable locations" and its statefulness.
---@brief ]]

---@tag lean.infoview.locations

local inductive = require 'std.inductive'

---@alias GoalLocationHyp FVarId
---@alias GoalLocationHypType {[1]: FVarId, [2]: SubexprPos}
---@alias GoalLocationHypValue {[1]: FVarId, [2]: SubexprPos}
---@alias GoalLocationTarget SubexprPos

---A location within a goal.
---
---It is either:
---  - one of the hypotheses; or
---  - (a subexpression of) the type of one of the hypotheses; or
---  - (a subexpression of) the value of one of the let-bound hypotheses; or
---  - (a subexpression of) the goal type.
---@class GoalLocation: Inductive
---@field with_subexpr_pos fun(self:GoalLocation, pos:SubexprPos):GoalLocation
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
      return self(pos)
    end,
  },
})

---The last locations for a given URI.
---
---Used to preserve selected locations if the cursor moves into and out of a
---window without really "moving" within the window.
---@type table<string, { [1]: lsp.Position, [2]: GoalsLocation[] }>
local selected_at = {}

---Locations within the goal state which have been selected ("shift+click"ed).
---@class Locations
---@field params lsp.TextDocumentPositionParams
---@field private subexpr_template? GoalsLocation a template used for any subexpression selection
local Locations = {}
Locations.__index = Locations

---Create a new Locations object.
function Locations:new(obj)
  return setmetatable(obj, self)
end

---Get the selected locations for the given position.
---@param params lsp.TextDocumentPositionParams
---@return GoalsLocation[]
function Locations.selected_at(params)
  local selected = selected_at[params.textDocument.uri]
  if not selected or not vim.deep_equal(selected[1], params.position) then
    return {}
  end
  return selected[2]
end

---Return Locations for a given position.
---
---If the cursor hasn't moved since we last asked for locations, retrieves the
---last selected locations.
---
---Otherwise, returns a new empty set of selected locations.
function Locations.at(params)
  local last = selected_at[params.textDocument.uri]
  if not last or not vim.deep_equal(last[1], params.position) then
    selected_at[params.textDocument.uri] = { params.position, {} }
  end
  return Locations:new { params = params }
end

---Is the given location selected?
---
---@param loc GoalsLocation
function Locations:is_selected(loc)
  return vim.iter(Locations.selected_at(self.params)):any(function(each)
    return vim.deep_equal(each, loc)
  end)
end

---Toggle whether the given location is selected.
---@param loc GoalsLocation
function Locations:toggle_selection(loc)
  local params, previous = unpack(selected_at[self.params.textDocument.uri])
  if not vim.deep_equal(params, self.params.position) then
    return
  end

  local new = vim
    .iter(previous)
    :filter(function(each)
      return not vim.deep_equal(each, loc)
    end)
    :totable()
  if #new == #previous then
    table.insert(new, loc)
  end
  selected_at[self.params.textDocument.uri][2] = new

  local infoview = require('lean.infoview').get_current_infoview()
  if not infoview then
    return
  end

  -- FIXME: The cursor nonsense is because we're improperly re-rendering
  --        more than we need to (and moving the cursor to the goal line)
  local cursor = vim.api.nvim_win_get_cursor(infoview.window)
  infoview.info.last_window:call(function()
    infoview:__update()
  end)
  vim.api.nvim_win_set_cursor(infoview.window, cursor)
end

---A Locations object which represents those within the given "template" location.
---@param location GoalsLocation
---@return Locations locations_in
function Locations:in_template(location)
  return Locations:new { params = self.params, subexpr_template = location }
end

---@return GoalsLocation
function Locations:template_with_subexpr_pos(pos)
  assert(self.subexpr_template, 'No subexpr template set.')
  return { -- FIXME: Add a proper GoalsLocation to clean this up.
    mvarId = self.subexpr_template.mvarId,
    loc = GoalLocation(self.subexpr_template.loc):with_subexpr_pos(pos):serialize(),
  }
end

---@param pos SubexprPos
function Locations:toggle_subexpr_selection(pos)
  self:toggle_selection(self:template_with_subexpr_pos(pos))
end

--TODO: have Locations handle constructing hlgroup()
---@param pos SubexprPos
function Locations:is_subexpr_selected(pos)
  return self:is_selected(self:template_with_subexpr_pos(pos))
end

return Locations
