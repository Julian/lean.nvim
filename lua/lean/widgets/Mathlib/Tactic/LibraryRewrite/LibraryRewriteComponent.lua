---@brief [[
---  The `rw??` ("library rewrite") Mathlib widget.
---@brief ]]

local Element = require('lean.tui').Element
local FilterDetails = require 'proofwidgets.filter_details'
local call_cancellable = require 'proofwidgets.call_cancellable'
local widgets = require 'lean.widgets'

---The `rw??` Mathlib widget.
---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local element, on_result = Element.async 'rw??'

  -- What could go wrong?
  local method = '_private.Mathlib.Tactic.Widget.LibraryRewrite.0.Mathlib.Tactic.LibraryRewrite.rpc'
  local _ = call_cancellable(ctx:subsession(), method, params, function(result)
    local _, _, props = unpack(result.component)
    on_result(FilterDetails(props, ctx))
  end)
  return element
end)
