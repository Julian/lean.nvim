---@mod tui.graphic Graphics with text fallback
---
---@brief [[
--- Renders a graphical Element when kitty graphics are available,
--- otherwise falls back to a text Element.
---@brief ]]

local kitty = require 'kitty'

local graphic = {}

---Render a graphical element if kitty is available, otherwise a text fallback.
---
---Both arguments are functions called lazily — only the chosen branch
---is evaluated.
---@param graphical fun(): Element? produces the graphical element (may return nil)
---@param fallback fun(): Element produces the text fallback
---@return Element
function graphic.render(graphical, fallback)
  if kitty.available() then
    local el = graphical()
    if el then
      return el
    end
  end
  return fallback()
end

return graphic
