local async = require 'std.async'

local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

--- Implements ProofWidgets.RefreshComponent
---
--- Displays HTML that updates over time as a background Lean thread pushes
--- new frames via the awaitRefresh RPC method.
---@param ctx RenderContext
---@param props { state: table, cancelTk: table }
---@return Element
return function(ctx, props)
  local element = Element:new {
    __async_init = function(rerender)
      -- Start the monitor call (fire-and-forget).
      -- It loops forever server-side and cancels the background computation
      -- when the RPC session closes.
      async.run(function()
        ctx:rpc_call('ProofWidgets.RefreshComponent.monitor', props)
      end)

      -- Poll for new HTML frames.
      async.run(function()
        local idx = 0
        while true do
          local response, err = ctx:rpc_call(
            'ProofWidgets.RefreshComponent.awaitRefresh',
            { state = props.state, oldIdx = idx }
          )
          if err or not response then
            break
          end
          idx = response.idx
          rerender(Html(response.html, ctx))
        end
      end)
    end,
  }
  return element
end
