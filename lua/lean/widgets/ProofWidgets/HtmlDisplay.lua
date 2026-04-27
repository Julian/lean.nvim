local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

---Implements ProofWidgets' HtmlDisplay widget for rendering HTML.
---@param ctx RenderContext
---@param props table
---@return Element?
return function(ctx, props)
  return Element:foldable {
    title = Element.title 'HTML Display',
    body = { Html(props.html, ctx) },
    gap = 1,
  }
end
