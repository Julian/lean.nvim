local Element = require('lean.tui').Element
local call_cancellable = require 'proofwidgets.call_cancellable'

return function(ctx, props)
  local params = vim.tbl_extend('error', props, {
    pos = ctx.params.position,
    goals = ctx:get_goals(),
    selectedLocations = ctx:selected_locations(),
  })

  local element = Element:new {}

  -- What could go wrong?
  local method =
    '_private.Mathlib.Tactic.Widget.InteractiveUnfold.0.Mathlib.Tactic.InteractiveUnfold.rpc._cancellable'
  call_cancellable(ctx:subsession(), method, params, function(response)
    element.text = response.text
  end)

  return element
end
