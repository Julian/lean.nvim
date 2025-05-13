local Element = require('lean.tui').Element
local ExprPresentation = require 'proofwidgets.expr_presentation'

---@param ctx RenderContext
---@param loc GoalsLocation
---@return Element
return function(ctx, loc)
  local goal = ctx:goal_with_mvar_id(loc.mvarId)
  if not goal then
    return {}
  end
  local params = { locations = { { goal.ctx, loc } } }
  local response, err = ctx:rpc_call('ProofWidgets.goalsLocationsToExprs', params)
  if err then
    return err
  end
  return Element:new { children = { ExprPresentation(ctx, response.exprs[1]) } }
end
