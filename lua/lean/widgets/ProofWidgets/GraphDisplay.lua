local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

---ProofWidgets' GraphDisplay widget.
---
---Renders a text representation of the graph until we support rendering real graphs.
---@param ctx RenderContext
---@param props { vertices: table[], edges: table[] }
---@return Element?
return function(ctx, props)
  local children = {}

  for _, vertex in ipairs(props.vertices) do
    local label = Element:new { text = vertex.id }
    local detail = vertex.details and Html(vertex.details, ctx)
    if detail then
      children[#children + 1] =
        Element:new { children = { label, Element:new { text = ': ' }, detail } }
    else
      children[#children + 1] = Element:new { text = '• ', children = { label } }
    end
  end

  if #props.edges > 0 then
    children[#children + 1] = Element:new { text = '\n' }
    for _, edge in ipairs(props.edges) do
      children[#children + 1] = Element:new { text = edge.source .. ' → ' .. edge.target }
    end
  end

  return Element:foldable {
    title = Element.title 'Graph',
    margin = 1,
    body = { Element:concat(children, '\n') },
  }
end
