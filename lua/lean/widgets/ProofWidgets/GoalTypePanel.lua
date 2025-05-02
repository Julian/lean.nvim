local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

---@class ExprPresentationData
---@field name string
---@field userName string
---@field html Html

---@param ctx RenderContext
---@return Element?
return function(ctx, _)
  local goals = ctx:get_goals()
  if not goals or #goals == 0 then
    return
  end

  -- from ProofWidgets4/widget/src/presentSelection.tsx
  local goal = goals[1]
  local location = { mvarId = goal.mvarId, loc = { target = '/' } } ---@type GoalsLocation
  local params = { locations = { { goal.ctx, location } } }
  local expr = ctx:rpc_call('ProofWidgets.goalsLocationsToExprs', params).exprs[1]

  local response = ctx:rpc_call('ProofWidgets.getExprPresentations', { expr = expr })
  local presentations = response.presentations ---@type ExprPresentationData[]
  ---@type ExprPresentationData each
  local children = vim
    .iter(presentations)
    :map(function(each)
      -- XXX: Implement the rest of rendering a presentation which looks like it
      --      involves some <select> element implementation
      return Html(each.html, ctx:subsession())
    end)
    :totable()
  return Element:new { children = children }
end
