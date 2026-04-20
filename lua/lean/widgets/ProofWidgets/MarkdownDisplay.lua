local Element = require('lean.tui').Element

---ProofWidgets' MarkdownDisplay widget.
---
---Renders the markdown contents as plain text until we implement a parser.
---@param _ctx RenderContext
---@param props { contents: string }
---@return Element?
return function(_ctx, props)
  return Element:new { text = props.contents }
end
