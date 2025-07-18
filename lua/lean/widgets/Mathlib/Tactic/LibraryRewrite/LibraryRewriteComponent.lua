---@brief [[
---  The `rw??` ("library rewrite") Mathlib widget.
---@brief ]]

local Html = require 'proofwidgets.html'
local a = require 'plenary.async'
local call_cancellable = require 'proofwidgets.call_cancellable'
local widgets = require 'lean.widgets'

---The `rw??` Mathlib widget.
---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  -- What could go wrong?
  local method =
    '_private.Mathlib.Tactic.Widget.InteractiveUnfold.0.Mathlib.Tactic.InteractiveUnfold.rpc._cancellable'
  local response, _cancel = call_cancellable(ctx:subsession(), method, params)
  return Html(a.await(response), ctx)
end)
