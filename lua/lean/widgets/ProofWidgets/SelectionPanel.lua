local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'
local log = require 'lean.log'

local NO_SELECTION_HELP = Element:concat({
  Element:new { text = 'Nothing selected. You can use' },
  Element.kbd 'gK',
  Element:new { text = 'in the infoview to select expressions in the goal.' },
}, ' ')

---@param ctx RenderContext
return function(ctx, _)
  local selected = ctx:selected_locations()
  if #selected == 0 then
    return NO_SELECTION_HELP
  end
  local elements = vim.iter(selected):map(function(loc) ---@param loc GoalsLocation
    local goal = ctx:goal_with_mvar_id(loc.mvarId)
    if not goal then
      return -- FIXME
    end
    local response, err = ctx:rpc_call('ProofWidgets.goalsLocationsToExprs', {
      locations = { { goal.ctx, loc } },
    })
    if err then
      log:error { err = err }
      return
    end
    local expr = response.exprs[1]

    -- TODO: Combine with GTP above (extract to helper)
    response = ctx:rpc_call('ProofWidgets.getExprPresentations', { expr = expr })
    local presentations = response.presentations ---@type ExprPresentationData[]
    ---@type ExprPresentationData each
    local children = vim
      .iter(presentations)
      :map(function(each)
        -- XXX: Implement the rest of rendering a presentation which looks like it
        --      involves some <select> element implementation
        return Html(each.html, ctx:subsession())
      end)
      :totable()
    return Element:new { children = children }
  end)
  if not elements:peek() then
    return
  end
  return Element:titled {
    title = '▼ Selected expressions:',
    title_hlgroup = 'Title',
    body = { Element:concat(elements:totable(), '\n') },
  }
end
