local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'
local call_cancellable = require 'proofwidgets.call_cancellable'
local widgets = require 'lean.widgets'

---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local element, on_result = Element.async 'unfold?'

  -- What could go wrong?
  local method =
    '_private.Mathlib.Tactic.Widget.InteractiveUnfold.0.Mathlib.Tactic.InteractiveUnfold.rpc'
  local _ = call_cancellable(ctx:subsession(), method, params, function(result)
    on_result(Html(result, ctx))
  end)
  return element
end)
