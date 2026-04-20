local InteractiveExpr = require 'proofwidgets.interactive_expr'

---ProofWidgets' InteractiveExpr widget.
---@param ctx RenderContext
---@param props { expr: table }
---@return Element?
return function(ctx, props)
  return InteractiveExpr(ctx, props.expr)
end
