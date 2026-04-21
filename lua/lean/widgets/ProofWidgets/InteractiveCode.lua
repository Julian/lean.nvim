local InteractiveCode = require 'lean.widget.interactive_code'

---ProofWidgets' InteractiveCode widget.
---@param ctx RenderContext
---@param props { fmt: CodeWithInfos }
---@return Element?
return function(ctx, props)
  return InteractiveCode(props.fmt, ctx:subsession())
end
