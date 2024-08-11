---@brief [[
--- Custom support for Lean widgets.
---
--- We aren't a web browser (yet?) so we don't have generic support for widgets
--- which execute via Javascipt.
---
--- But this module "decompiles" specific widgets into TUI-accessible
--- components.
---@brief ]]

local Element = require('lean.tui').Element
local dedent = require('lean._util').dedent

--- @alias SuggestionText string

--- @class Suggestion
--- @field suggestion SuggestionText Text to be used as a replacement via a code action.
--- @field preInfo? string Optional info to be printed immediately before replacement text in a widget.
--- @field postInfo? string Optional info to be printed immediately after replacement text in a widget.

--- @class TryThisParams
--- @field suggestions Suggestion[]

---@type table<string, fun(props: any): Element>
local SUPPORTED = {
  ---@param props TryThisParams
  ["Lean.Meta.Tactic.TryThis.tryThisWidget"] = function(props)
    local blocks = vim.iter(props.suggestions):map(function(each)
      local pre = (each.preInfo or ''):gsub('\n', '\n  ')
      local post = (each.postInfo or ''):gsub('\n', '\n  ')
      local text = vim.iter({ pre, each.suggestion, post }):join('\n')
      return Element:new {text = text }
    end)
    return Element:new{
      text = '▶ suggestions:\n',
      children = blocks:totable(),
    }
  end
}

---@param widget UserWidgetInstance
---@return Element[]?
local function to_element(widget)
  local cross_compiler = SUPPORTED[widget.id]
  if cross_compiler then
    return cross_compiler(widget.props)
  else
    local message = dedent [[
      %q is not a supported Lean widget type.
      If you think it could be, please file an issue with lean.nvim!
    ]]
    vim.notify_once(message:format(widget.id), vim.log.levels.DEBUG)
  end
end

return to_element
