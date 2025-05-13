local Element = require('lean.tui').Element
local GoalsLocationPresentation = require 'proofwidgets.present_selection'

local NO_SELECTION_HELP = Element:concat({
  Element:new { text = 'Nothing selected. You can use' },
  Element.kbd 'gK',
  Element:new { text = 'in the infoview to select expressions in the goal.' },
}, ' ')

---@param ctx RenderContext
return function(ctx, _)
  local selected = ctx:selected_locations()
  if #selected == 0 then
    return NO_SELECTION_HELP
  end
  local elements = vim.iter(selected):map(function(loc) ---@param loc GoalsLocation
    return GoalsLocationPresentation(ctx, loc)
  end)
  return Element:titled {
    title = '▼ Selected expressions:',
    title_hlgroup = 'Title',
    body = { Element:concat(elements:totable(), '\n') },
  }
end
