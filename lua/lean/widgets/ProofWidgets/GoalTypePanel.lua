local Element = require('lean.tui').Element
local GoalsLocationPresentation = require 'proofwidgets.present_selection'

---From https://github.com/leanprover-community/ProofWidgets4/blob/main/widget/src/goalTypePanel.tsx
---@param ctx RenderContext
---@return Element?
return function(ctx, _)
  local goals = ctx:get_goals()
  if not goals or #goals == 0 then
    return
  end

  local goal = goals[1]
  local location = { mvarId = goal.mvarId, loc = { target = '/' } } ---@type GoalsLocation
  return Element:titled {
    title = '▼ Main goal type',
    margin = 1,
    title_hlgroup = 'Title',
    body = { GoalsLocationPresentation(ctx, location) },
  }
end
