---@brief [[
---  The `ProofStatus` widget from Verbose Lean.
---
--- (It's not namespaced, so it shows up here "globally".)
---@brief ]]

local Html = require 'proofwidgets.html'

---@class ProofStatusProps
---@field message string
---@field cssClasses string

---@param ctx RenderContext
---@param props ProofStatusProps
return function(ctx, props)
  local response, err = ctx:rpc_call('ProofStatus.rpc', props)
  if err then
    return err
  end
  return Html(response, ctx)
end
