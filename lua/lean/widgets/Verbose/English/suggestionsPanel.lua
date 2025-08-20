---@brief [[
---  The (English) `suggestionPanel` widget from Patrick Massot's Verbose Lean.
---@brief ]]

local Html = require 'proofwidgets.html'
local widgets = require 'lean.widgets'

---The `suggestionPanel` widget from Patrick Massot's Verbose Lean.
---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local response, err = ctx:rpc_call('Verbose.English.suggestionsPanel.rpc', params)
  if err then
    return err
  end
  return Html(response, ctx)
end)
