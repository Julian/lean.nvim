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
    table.insert(children, ctx:edit_link(each[1], props.range, each[1]))
    if each.info and each.info ~= '' then
      table.insert(children, Element:new { text = each.info })
    end
    return Element:new { children = children }
  end)
  return Element:foldable {
    title = Element.title('LLMStep suggestion:', 'widgetSuggestion'),
    margin = 1,
    body = blocks:totable(),
  }
end
