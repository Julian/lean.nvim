---@brief [[
---  The `unfold?` Mathlib widget.
---@brief ]]

local Html = require 'proofwidgets.html'
local widgets = require 'lean.widgets'

---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local response, err = ctx:rpc_call('Mathlib.Tactic.InteractiveUnfold.rpc', params)
  if err then
    return err
  end
  return Html(response, ctx)
end)
