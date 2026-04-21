local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

---ProofWidgets' PenroseDiagram widget
---@param ctx RenderContext
---@param props { embeds: table[], dsl: string, sty: string, sub: string }
---@return Element?
return function(ctx, props)
  local children = {}
  for _, embed in ipairs(props.embeds) do
    local name, html = embed[1], embed[2]
    children[#children + 1] = Element:new {
      children = { Element:new { text = name .. ': ' }, Html(html, ctx) },
    }
  end

  if #children == 0 then
    return Element:new { text = '[Penrose diagram]' }
  end

  return Element:titled {
    title = '▼ Diagram',
    title_hlgroup = 'Title',
    margin = 1,
    body = { Element:concat(children, '\n') },
  }
end
