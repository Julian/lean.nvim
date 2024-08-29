---@brief [[
--- Custom support for Lean (user) widgets.
---
--- We aren't a web browser (yet?) so we don't have generic support for widgets
--- which execute via Javascipt.
---
--- But this module "decompiles" specific widgets into TUI-accessible
--- components.
---@brief ]]

local Element = require('lean.tui').Element
local dedent = require('lean._util').dedent

---@alias WidgetRenderer fun(self: Widget, props: any): Element[]?

--- A Lean user widget.
--- @class Widget
--- @field element WidgetRenderer
local Widget = {}
Widget.__index = Widget

--- @class WidgetNewArgs
--- @field element WidgetRenderer

--- Create a new Widget.
--- @param args WidgetNewArgs
--- @return Widget
function Widget:new(args)
  local obj = { element = args.element }
  return setmetatable(obj, self)
end

--- A null widget which indicates it is standing in for one not-yet-supported.
--- @param id string the ID of the user widget we are not implementing
--- @return Widget
function Widget.unsupported(id)
  return Widget:new {
    element = function()
      local message = dedent [[
        %q is not a supported Lean widget type.
        If you think it could be, please file an issue with lean.nvim!
      ]]
      vim.notify_once(message:format(id), vim.log.levels.DEBUG)
    end,
  }
end

--- A registry of `Widget`s which we essentially reimplement in Lua rather than
--- by executing their Javascript source modules.
local BYPASSED_WIDGETS = vim.defaulttable(Widget.unsupported)

---Implement the Lean user widget with the given ID (by
---bypassing its Javascript and calling the given function instead).
---@param id string
---@param element WidgetRenderer
---@return nil
local function implement(id, element)
  BYPASSED_WIDGETS[id] = Widget:new { element = element }
end

---Render a supported widget to one or more TUI `Element`s.
---
---Unsupported widgets are ignored after logging a notice.
---@param user_widget UserWidget
---@return Widget
function Widget.from_user_widget(user_widget)
  return BYPASSED_WIDGETS[user_widget.id]
end

--- @alias SuggestionText string

--- @class Suggestion
--- @field suggestion SuggestionText Text to be used as a replacement via a code action.
--- @field preInfo? string Optional info to be printed immediately before replacement text in a widget.
--- @field postInfo? string Optional info to be printed immediately after replacement text in a widget.

--- @class TryThisParams
--- @field suggestions Suggestion[]

---@param props TryThisParams
implement('Lean.Meta.Tactic.TryThis.tryThisWidget', function(_, props)
  local blocks = vim.iter(props.suggestions):map(function(each)
    local pre = (each.preInfo or ''):gsub('\n', '\n  ')
    local post = (each.postInfo or ''):gsub('\n', '\n  ')
    local text = vim.iter({ pre, each.suggestion, post }):join '\n'
    return Element:new { text = text }
  end)
  return Element:new {
    text = '▶ suggestions:',
    children = blocks:totable(),
  }
end)

return {
  Widget = Widget,
  implement = implement,

  ---Render the given response to one or more TUI elements.
  ---@param response? UserWidgets
  ---@return Element[]? elements
  render_response = function(response)
    if response then
      ---@param each UserWidgetInstance
      return vim
        .iter(response.widgets)
        :map(function(each)
          return Widget.from_user_widget(each):element(each.props)
        end)
        :totable()
    end
  end,
}
