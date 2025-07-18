local Element = require('lean.tui').Element
local call_cancellable = require 'proofwidgets.call_cancellable'
local widgets = require 'lean.widgets'

---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local element = Element:new {}

  -- What could go wrong?
  local method =
    '_private.Mathlib.Tactic.Widget.InteractiveUnfold.0.Mathlib.Tactic.InteractiveUnfold.rpc._cancellable'
  call_cancellable(ctx:subsession(), method, params, function(response)
    element.text = response.text or ''
  end)

  return element
end)
