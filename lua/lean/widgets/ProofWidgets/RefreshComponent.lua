local async = require 'std.async'

local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

--- Implements ProofWidgets.RefreshComponent
---
--- Displays HTML that updates over time as a background Lean thread pushes
--- new frames via the awaitRefresh RPC method.
---
--- A subtle point: each tree rebuild (cursor move, panel re-render, ...)
--- creates a fresh RefreshComponent element with its own polling loop. If
--- the previous element's loop is left running, every server frame it
--- receives forces a full `renderer:render()` on the orphaned subtree,
--- which compounds with every rebuild until the infoview is constantly
--- re-rendering itself ("hourglass + flicker even when idle"). To avoid
--- this we publish a `__state` cancel handle; `transfer_state` carries it
--- to the new element which immediately cancels the old polling loop.
---@param ctx RenderContext
---@param props { state: table, cancelTk: table }
---@return Element
return function(ctx, props)
  local cancelled = false

  local element = Element:new {
    __async_init = function(rerender)
      -- Start the monitor call (fire-and-forget). It loops forever server-side
      -- and cancels the background computation when the RPC session closes.
      async.run(function()
        ctx:rpc_call('ProofWidgets.RefreshComponent.monitor', props)
      end)

      -- Poll for new HTML frames. Bail as soon as a newer element has
      -- adopted our position (via `__state`), otherwise the orphaned loop
      -- would keep firing `renderer:render()` after every server frame.
      async.run(function()
        local idx = 0
        while not cancelled do
          local response, err = ctx:rpc_call(
            'ProofWidgets.RefreshComponent.awaitRefresh',
            { state = props.state, oldIdx = idx }
          )
          if err or not response or cancelled then
            break
          end
          idx = response.idx
          rerender(Html(response.html, ctx))
        end
      end)
    end,
  }

  element.__state = {
    snapshot = function()
      return function()
        cancelled = true
      end
    end,
    restore = function(_, cancel_previous)
      cancel_previous()
    end,
  }

  return element
end
