---@brief [[
--- A widget for a clickable link (or icon) that inserts text into the document at a given position.
---
--- In particular, used by the `Try This` widget on versions of Lean v4.25+.
---@brief ]]

local codicons = require 'tui.codicons'

local Element = require('lean.tui').Element
local log = require 'lean.log'

---@class AcceptSuggestionText
---@field kind 'text'
---@field hoverText string Displayed on hover
---@field linkText string Displayed as the text of the link

---@class AcceptSuggestionIcon
---@field kind 'icon'
---@field hoverText string Displayed on hover
---@field codiconName string one of the icons at https://microsoft.github.io/vscode-codicons/dist/codicon.html
---@field gaps boolean whether there are clickable spaces surrounding the icon

---@alias AcceptSuggestionProps AcceptSuggestionText | AcceptSuggestionIcon

---@class TextInsertionParams
---@field acceptSuggestionProps AcceptSuggestionProps
---@field range lsp.Range
---@field suggestion string

---@param ctx RenderContext
---@param props TextInsertionParams
return function(ctx, props)
  local accept = props.acceptSuggestionProps
  local content ---@type string|Element
  if accept.kind == 'text' then
    content = accept.linkText
  elseif accept.kind == 'icon' then
    local name = ('[%s]'):format(accept.codiconName)
    local icon = codicons.element(accept.codiconName, { fallback = Element:new { text = name } })
      or Element:new { text = name }
    if accept.gaps then
      content = Element:new { children = { Element.text ' ', icon, Element.text ' ' } }
    else
      content = icon
    end
  else
    log:error {
      message = 'Unexpected `acceptSuggestionProps` kind',
      props = props,
    }
    return
  end

  local link = ctx:edit_link(content, props.range, props.suggestion)
  if accept.hoverText then
    link:add_tooltip(Element:new { text = accept.hoverText })
  end
  return link
end
