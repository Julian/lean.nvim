---From https://github.com/leanprover-community/ProofWidgets4/blob/main/widget/src/exprPresentation.tsx

local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'
local InteractiveExpr = require 'proofwidgets.interactive_expr'

---@alias SelectedPresentation
---| { tag: "auto" }
---| { tag: "manual", name: string? }

---@class ExprWithCtx

---@class ExprPresentationData
---@field name string
---@field userName string
---@field html any

---Display the given expression using an `ExprPresenter`.
---
---The server is queried for registered `ExprPresenter`s.
---
--- A dropdown is shown allowing the user to select which of these should be used to display the expression.
---@param ctx RenderContext
---@param expr ExprWithCtx
---@return Element
return function(ctx, expr)
  local response, err = ctx:rpc_call('ProofWidgets.getExprPresentations', { expr = expr })
  if err then
    return err
  end
  local presentations = {}
  for _, each in ipairs(response.presentations) do
    table.insert(presentations, each)
    presentations[each.name] = each
  end
  table.insert(presentations, { name = 'none', userName = 'Default' })

  local selection_name
  if #response.presentations > 0 then
    selection_name = presentations[1].name
  else
    selection_name = 'none'
  end

  local selection
  selection = { tag = 'auto' } ---@type SelectedPresentation

  local function selection_to_child()
    if selection.tag == 'auto' then
      return Html(presentations[1].html, ctx)
    elseif selection.name ~= 'none' then
      return Html(presentations[selection.name].html, ctx)
    elseif selection.name == 'none' then
      return InteractiveExpr(ctx, expr)
    end
  end

  local element = Element:new { children = { selection_to_child() } }

  return Element:new {
    children = {
      element,
      Element:new { text = '\t\t\t\t' }, -- FIXME: really we need Element:flex
      Element.select(
        presentations,
        { ---@type SelectionOpts<SelectedPresentation>
          initial = presentations[selection_name],
          format_item = function(item)
            return item.userName
          end,
        },
        ---@param choice ExprPresentationData
        function(choice)
          selection = { tag = 'manual', name = choice.name }
          element:set_children { selection_to_child() }
        end
      ),
    },
  }
end
