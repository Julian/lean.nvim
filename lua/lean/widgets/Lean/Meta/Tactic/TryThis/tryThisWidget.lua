---@brief [[
--- The `Try This` widget on old versions of Lean pre-v4.23.
---@brief ]]

local Element = require('lean.tui').Element

---@class LegacyTryThisParams
---@field suggestions TryThis.Suggestion[]
---@field range lsp.Range
---@field header string
---@field isInline boolean
---@field style any

---@param ctx RenderContext
---@param props LegacyTryThisParams
return function(ctx, props)
  local blocks = vim.iter(ipairs(props.suggestions)):map(function(i, each)
    local children = {
      i ~= 1 and Element:new { text = '\n' } or nil,
    }
    if each.preInfo then
      table.insert(children, Element:new { text = each.preInfo })
    end
    table.insert(children, ctx:edit_link(each.suggestion, props.range, each.suggestion))
    if each.postInfo then
      table.insert(children, Element:new { text = each.postInfo })
    end
    return Element:new { children = children }
  end)
  return Element:foldable {
    title = Element.title('suggestion:', 'widgetSuggestion'),
    margin = 1,
    body = blocks:totable(),
  }
end
