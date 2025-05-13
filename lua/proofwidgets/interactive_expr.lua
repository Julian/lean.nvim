---From https://github.com/leanprover-community/ProofWidgets4/blob/main/widget/src/interactiveExpr.tsx
local InteractiveCode = require 'lean.widget.interactive_code'

---@param ctx RenderContext
---@param expr ExprWithCtx
---@return Element
return function(ctx, expr)
  local response = ctx:rpc_call('ProofWidgets.ppExprTagged', { expr = expr })
  return InteractiveCode(response, ctx:subsession())
end
