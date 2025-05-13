local a = require 'plenary.async'

local Element = require('lean.tui').Element
local InteractiveCode = require 'lean.widget.interactive_code'

---From https://github.com/leanprover-community/ProofWidgets4/blob/main/widget/src/interactiveExpr.tsx

---@param ctx RenderContext
---@param expr ExprWithCtx
---@return Element
return function(ctx, expr)
  local element
  element = Element:new {}
  vim.schedule(a.void(function()
    local response, err = ctx:rpc_call('ProofWidgets.ppExprTagged', { expr = expr })
    if err then
      return err
    end
    element:set_children { InteractiveCode(response, ctx:subsession()) }
  end))
  return element
end
