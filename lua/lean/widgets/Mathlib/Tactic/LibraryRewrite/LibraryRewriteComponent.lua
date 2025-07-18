---@brief [[
---  The `rw??` ("library rewrite") Mathlib widget.
---@brief ]]

local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'
local call_cancellable = require 'proofwidgets.call_cancellable'
local widgets = require 'lean.widgets'

---The `rw??` Mathlib widget.
---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local element, on_result = Element.async()

  -- What could go wrong?
  local method =
    '_private.Mathlib.Tactic.Widget.LibraryRewrite.0.Mathlib.Tactic.LibraryRewrite.rpc._cancellable'
  local _ = call_cancellable(ctx:subsession(), method, params, function(result)
    on_result(Html(result.all, ctx))
  end)
  return element
end)
