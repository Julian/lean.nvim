---@brief [[
---  Le widget `suggestionPanel` (français) de Verbose Lean de Patrick Massot.
---@brief ]]

local Html = require 'proofwidgets.html'
local widgets = require 'lean.widgets'

---Le widget `suggestionPanel` (français) de Verbose Lean de Patrick Massot.
---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local response, err = ctx:rpc_call('Verbose.French.suggestionsPanel.rpc', params)
  if err then
    return err
  end
  return Html(response, ctx)
end)
