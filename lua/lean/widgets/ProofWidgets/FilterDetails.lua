local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

---ProofWidgets's FilterDetails widget.
---
---Renders a summary with filtered content.
---@param ctx RenderContext
---@param props { summary: Html, filtered: Html, all: Html, initiallyFiltered: boolean? }
---@return Element?
return function(ctx, props)
  local initially_filtered = props.initiallyFiltered
  if initially_filtered == nil then
    initially_filtered = true
  end
  local content = initially_filtered and props.filtered or props.all
  return Element:new {
    children = { Html(props.summary, ctx), Element.text '\n', Html(content, ctx) },
  }
end
