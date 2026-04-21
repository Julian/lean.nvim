local ExprPresentation = require 'proofwidgets.expr_presentation'

---ProofWidgets' Presentation.ExprPresentation
---
---Queries for registered `ExprPresenters` and renders the expression with a dropdown selector.
---@param ctx RenderContext
---@param props { expr: table }
---@return Element?
return function(ctx, props)
  return ExprPresentation(ctx, props.expr)
end
