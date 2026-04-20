local Element = require('lean.tui').Element
local TaggedTextMsgEmbed = require('lean.widget.interactive_diagnostic').TaggedTextMsgEmbed

---ProofWidgets' InteractiveMessage widget.
---@param ctx RenderContext
---@param props { msg: table }
---@return Element?
return function(ctx, props)
  local sess = ctx:subsession()
  local response, err = sess:msgToInteractive(props.msg, 0)
  if err then
    return Element:new { text = vim.inspect(err) }
  end
  return TaggedTextMsgEmbed(response, sess)
end
