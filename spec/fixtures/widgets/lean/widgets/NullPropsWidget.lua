local Element = require('lean.tui').Element
local widgets = require 'lean.widgets'

return widgets.panel(function(_, params)
  local n = #params.selectedLocations
  return Element:new { text = ('PANEL WIDGET WITH %d SELECTIONS'):format(n) }
end)
