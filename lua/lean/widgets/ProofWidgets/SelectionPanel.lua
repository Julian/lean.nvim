local Element = require('lean.tui').Element
local GoalsLocationPresentation = require 'proofwidgets.present_selection'
local widgets = require 'lean.widgets'

---@param ctx RenderContext
---@param params PanelWidgetProps
return widgets.panel(function(ctx, params)
  local elements = vim.iter(params.selectedLocations):map(function(loc) ---@param loc GoalsLocation
    return GoalsLocationPresentation(ctx, loc)
  end)
  return Element:foldable {
    title = Element.title 'Selected expressions:',
    body = { Element:concat(elements:totable(), '\n') },
  }
end)
