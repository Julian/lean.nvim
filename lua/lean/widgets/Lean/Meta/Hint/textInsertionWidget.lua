---@brief [[
--- A widget for a clickable link (or icon) that inserts text into the document at a given position.
---
--- In particular, used by the `Try This` widget on versions of Lean v4.25+.
---@brief ]]

local Element = require('lean.tui').Element

---@class AcceptSuggestionText
---@field kind 'text'
---@field hoverText string Displayed on hover
---@field linkText string Displayed as the text of the link

---@class AcceptSuggestionIcon
---@field kind 'icon'
---@field hoverText string Displayed on hover
---@field codiconName string one of the icons at https://microsoft.github.io/vscode-codicons/dist/codicon.html
---@field gaps boolean hether there are clickable spaces surrounding the icon

---@alias AcceptSuggestionProps AcceptSuggestionText | AcceptSuggestionIcon

---@class TextInsertionParams
---@field acceptSuggestionProps AcceptSuggestionProps
---@field range lsp.Range
---@field suggestion string

---@param ctx RenderContext
---@param props TextInsertionParams
return function(ctx, props)
  -- TODO: hoverText
  return Element:new {
    text = props.acceptSuggestionProps.linkText,
    children = Element:new { text = props.suggestion },
    highlightable = true,
    hlgroup = 'widgetLink',
    events = {
      click = function()
        ctx:apply_edits {
          { range = props.range, newText = props.suggestion },
        }
      end,
    },
  }
end
