local MakeEditLink = require 'proofwidgets.make_edit_link'

--- Implements ProofWidgets.Component.MakeEditLink
---@param ctx RenderContext
---@param props MakeEditLinkProps
---@return Element?
return function(ctx, props)
  local title = props.title or 'Apply edit'
  return MakeEditLink(props, { require('lean.tui').Element:new { text = title } }, ctx)
end
