---@brief [[
--- The `Try This` widget on versions of Lean v4.24 (only).
---@brief ]]

local Element = require('lean.tui').Element

---@alias SuggestionText string

---@class TryThis.Suggestion
---@field suggestion SuggestionText Text to be used as a replacement via a code action.
---@field preInfo? string Optional info to be printed immediately before replacement text in a widget.
---@field postInfo? string Optional info to be printed immediately after replacement text in a widget.

---A code action suggestion associated with a hint in a message.
---
---Refer to `TryThis.Suggestion`. This extends that structure with several fields specific to inline
---hints.
---@class Suggestion: TryThis.Suggestion

---@class TryThisParams
---@field diff { type: 'insertion' | 'deletion' | 'unchanged', text: string }[]
---@field range lsp.Range
---@field suggestion string

---@param ctx RenderContext
---@param props TryThisParams
return function(ctx, props)
  return Element:new {
    text = props.suggestion,
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
