local inductive = require 'std.inductive'

local CodeWithInfos = require('lean.widget.interactive_code').CodeWithInfos
local Element = require('lean.tui').Element
local InteractiveGoal = require('lean.widget.interactive_goal').interactive_goal
local TaggedText = require 'lean.widget.tagged_text'
local log = require 'lean.log'
local widgets = require 'lean.widgets'

local interactive_diagnostic = {}

local function abbreviate_common_prefix(a, b)
  local i = a:find '[.]'
  local j = b:find '[.]'
  if i and j and i == j and a:sub(1, i) == b:sub(1, i) then
    return abbreviate_common_prefix(a:sub(i + 1), b:sub(i + 1))
  elseif not i and j and b:sub(1, j - 1) == a then
    return b:sub(j + 1)
  elseif a == b then
    return ''
  else
    return b
  end
end

---@class MsgEmbedExpr
---@field expr CodeWithInfos A piece of Lean code with elaboration/typing data.

---@class MsgEmbedGoal
---@field goal InteractiveGoal An interactive goal display.

---@class MsgEmbedWidget
---@field widget WidgetEmbed A widget instance.

---@class MsgEmbedTrace
---@field trace TraceEmbed Traces are too costly to print eagerly.

---@alias MsgEmbed MsgEmbedExpr | MsgEmbedGoal | MsgEmbedWidget | MsgEmbedTrace

interactive_diagnostic.MsgEmbed = inductive('MsgEmbed', {
  expr = function(_, ...)
    return CodeWithInfos(...)
  end,

  goal = function(_, ...)
    return InteractiveGoal(...)
  end,

  ---@param embed WidgetEmbed
  ---@param sess Subsession
  widget = function(_, embed, sess)
    local widget = widgets.render(embed.wi, sess)
    if widget then
      return widget
    end

    log:debug {
      message = 'Widget rendering failed, falling back to the `alt` widget.',
      widget = embed,
    }
    return interactive_diagnostic.TaggedTextMsgEmbed(embed.alt, sess)
  end,

  ---@param trace TraceEmbed
  ---@param sess Subsession
  trace = function(_, trace, sess, parent_cls)
    local element = Element:new {}

    local cls = trace.cls
    local children = trace.children
    local children_err

    local abbr_cls = cls
    if parent_cls ~= nil then
      abbr_cls = abbreviate_common_prefix(parent_cls, cls)
    end

    local is_open = not trace.collapsed

    local click
    local function render()
      local header = Element:new {
        text = ('%s[%s] '):format((' '):rep(trace.indent), abbr_cls),
      }
      header:add_child(interactive_diagnostic.TaggedTextMsgEmbed(trace.msg, sess))
      if children.lazy or #children.strict > 0 then
        header.highlightable = true
        header.events = { click = click }
        header:add_child(Element:new { text = (is_open and ' ▼' or ' ▶') .. '\n' })
      else
        header:add_child(Element:new { text = '\n' })
      end

      element:set_children { header }

      if is_open then
        if children_err then
          element:add_child(Element:new { text = vim.inspect(children_err) })
        elseif children.strict ~= nil then
          for _, child in ipairs(children.strict) do
            element:add_child(interactive_diagnostic.TaggedTextMsgEmbed(child, sess, cls))
          end
        end
      end
      return true
    end

    click = function(ctx)
      if is_open then
        is_open = false
      else
        is_open = true

        if children.lazy ~= nil then
          local new_kids, err = sess:lazyTraceChildrenToInteractive(children.lazy)
          children_err = err
          children = { strict = new_kids }
        end
      end
      render()
      ctx.rerender()
    end

    render()
    return element
  end,
})

---@class TaggedText.MsgEmbed: TaggedText
---@field append? TaggedText.MsgEmbed[]
---@field tag? {[1]: MsgEmbed, [2]: ''} the second field happens to always the empty string

interactive_diagnostic.TaggedTextMsgEmbed = TaggedText('MsgEmbed', function(msg_embed, _, ...)
  return interactive_diagnostic.MsgEmbed(msg_embed, ...)
end)

return interactive_diagnostic
