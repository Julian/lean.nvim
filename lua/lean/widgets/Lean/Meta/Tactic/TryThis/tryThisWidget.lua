local Element = require('lean.tui').Element

---@alias SuggestionText string

---@class Suggestion
---@field suggestion SuggestionText Text to be used as a replacement via a code action.
---@field preInfo? string Optional info to be printed immediately before replacement text in a widget.
---@field postInfo? string Optional info to be printed immediately after replacement text in a widget.

---@class TryThisParams
---@field suggestions Suggestion[]
---@field range lsp.Range
---@field header string
---@field isInline boolean
---@field style any

---@param ctx RenderContext
---@param props TryThisParams
return function(ctx, props)
  local blocks = vim.iter(ipairs(props.suggestions)):map(function(i, each)
    local children = {
      i ~= 1 and Element:new { text = '\n' } or nil,
    }
    if each.preInfo then
      table.insert(children, Element:new { text = each.preInfo })
    end
    table.insert(
      children,
      Element:new {
        text = each.suggestion,
        highlightable = true,
        hlgroup = 'widgetLink',
        events = {
          click = function()
            local bufnr = ctx:bufnr()
            if not bufnr then
              return
            end

            ---@type lsp.TextEdit
            local edit = { range = props.range, newText = each.suggestion }
            vim.lsp.util.apply_text_edits({ edit }, bufnr, 'utf-16')

            local this_infoview = require('lean.infoview').get_current_infoview()
            local this_info = this_infoview and this_infoview.info
            local last_window = this_info and this_info.last_window
            if last_window and vim.api.nvim_win_get_buf(last_window) == bufnr then
              vim.api.nvim_set_current_win(last_window)
            end
          end,
        },
      }
    )
    if each.postInfo then
      table.insert(children, Element:new { text = each.postInfo })
    end
    return Element:new { children = children }
  end)
  return Element:titled {
    title = '▼ suggestion:',
    title_hlgroup = 'widgetSuggestion',
    margin = 1,
    body = blocks:totable(),
  }
end
