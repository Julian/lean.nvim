local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

--- Implements ProofWidgets.Component.HtmlDisplayPanel
---@param ctx RenderContext
---@param props table
---@return Element?
return function(ctx, props)
  return Element:titled {
    title = '▼ HTML Display',
    body = { Html(props.html, ctx) },
    title_hlgroup = 'Title',
    margin = 1,
  }
end
