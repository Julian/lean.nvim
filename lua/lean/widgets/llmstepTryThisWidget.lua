local Element = require('lean.tui').Element

---@class LLMStepSuggestion: { [1]: SuggestionText, [2]: LLMStepCheckResult }

---@class LLMStepTryThisParams
---@field tactic string
---@field suggestions LLMStepSuggestion[]
---@field range lsp.Range
---@field info string

---@alias LLMStepCheckResult "ProofDone" | "Valid" | "Invalid"

---LLMStep's slightly modified version of the Try This widget.
---
---See https://github.com/cmu-l3/llmlean/blob/09a4c97e7f676dfa2dba146e89aee5b0bfe524a7/LLMlean/LLMstep.lean#L25
---@param ctx RenderContext
---@param props LLMStepTryThisParams
return function(ctx, props)
  local blocks = vim.iter(ipairs(props.suggestions)):map(function(i, each)
    local children = {
      i ~= 1 and Element:new { text = '\n' } or nil,
    }
    table.insert(
      children,
      Element:new {
        text = each[1],
        highlightable = true,
        hlgroup = 'widgetLink',
        events = {
          click = function()
            ctx:apply_edits {
              { range = props.range, newText = each[1] },
            }
          end,
        },
      }
    )
    if each.info and each.info ~= '' then
      table.insert(children, Element:new { text = each.info })
    end
    return Element:new { children = children }
  end)
  return Element:titled {
    title = '▼ LLMStep suggestion:',
    title_hlgroup = 'widgetSuggestion',
    margin = 1,
    body = blocks:totable(),
  }
end
