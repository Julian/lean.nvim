local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

---ProofWidgets's FilterDetails widget.
---
---A collapsible disclosure whose summary carries a filter toggle that
---switches the body between filtered and unfiltered content. The toggle
---state survives a tree rebuild via a `__state` handle.
---@param ctx RenderContext
---@param props { summary: Html, filtered: Html, all: Html, initiallyFiltered: boolean? }
---@return Element?
return function(ctx, props)
  local is_filtered = props.initiallyFiltered ~= false

  local body
  local filter

  local function refresh()
    body:set_children { Html(is_filtered and props.filtered or props.all, ctx) }
    filter.text = is_filtered and 'show more' or 'show less'
  end

  body = Element:new {
    children = { Html(is_filtered and props.filtered or props.all, ctx) },
  }
  -- The foldable container owns its own `__state` for open/close. Filter
  -- state lives on `body` (the foldable's stable walk target), so both
  -- handles coexist along the path `transfer_state` already traverses.
  body.__state = {
    snapshot = function()
      return is_filtered
    end,
    restore = function(_, saved)
      if is_filtered == saved then
        return
      end
      is_filtered = saved
      refresh()
    end,
  }

  filter = Element.link {
    text = is_filtered and 'show more' or 'show less',
    action = function(click_ctx)
      is_filtered = not is_filtered
      refresh()
      click_ctx.rerender()
    end,
  }

  return Element:foldable {
    title = Element:new {
      children = {
        Html(props.summary, ctx),
        Element.text '\t\t\t\t',
        filter,
      },
    },
    body = { body },
    gap = 1,
  }
end
