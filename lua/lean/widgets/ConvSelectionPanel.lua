---@brief [[
---  The `conv?` Mathlib widget.
---
--- (It's not namespaced, so it shows up here "globally".)
---@brief ]]

local Html = require 'proofwidgets.html'
local widgets = require 'lean.widgets'

---The `conv?` Mathlib widget.
---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local response, err = ctx:rpc_call('ConvSelectionPanel.rpc', params)
  if err then
    return err
  end
  return Html(response, ctx)
end)
