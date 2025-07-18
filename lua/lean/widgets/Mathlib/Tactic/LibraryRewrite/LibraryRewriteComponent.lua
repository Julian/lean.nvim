---@brief [[
---  The `rw??` ("library rewrite") Mathlib widget.
---@brief ]]

local Element = require('lean.tui').Element
local call_cancellable = require 'proofwidgets.call_cancellable'
local widgets = require 'lean.widgets'

---The `conv?` Mathlib widget.
---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local method =
    '_private.Mathlib.Tactic.Widget.InteractiveUnfold.0.Mathlib.Tactic.InteractiveUnfold.rpc._cancellable'
  call_cancellable(ctx:subsession(), method, params, function(response)
    vim.print(response)
  end)
end)
