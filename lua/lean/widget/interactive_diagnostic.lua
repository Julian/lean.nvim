local inductive = require 'std.inductive'

local InteractiveCode = require 'lean.widget.interactive_code'
local Element = require('lean.tui').Element
local InteractiveGoal = require('lean.widget.interactive_goal').Goal
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

---Render a trace embed.
---
---Shared between MsgEmbed.trace and the highlighted variant.
---@param trace TraceEmbed
---@param sess ReconnectingSubsession
---@param parent_cls? string
---@param tagged_text_renderer function the TaggedText renderer for recursive content
local function render_trace(trace, sess, parent_cls, tagged_text_renderer)
  local cls = trace.cls
  local children = trace.children
  local children_err

  local abbr_cls = cls
  if parent_cls ~= nil then
    abbr_cls = abbreviate_common_prefix(parent_cls, cls)
  end

  local title = Element:new {
    children = {
      Element:new { text = ('[%s] '):format(abbr_cls) },
      tagged_text_renderer(trace.msg, sess),
      Element:new { text = '\n' },
    },
  }

  local function build_body()
    if children_err then
      return { Element:new { text = vim.inspect(children_err) } }
    elseif children.strict then
      return vim
        .iter(children.strict)
        :map(function(child)
          return tagged_text_renderer(child, sess, cls)
        end)
        :totable()
    end
    return {}
  end

  local lazy = children.lazy

  local section = Element:foldable {
    title = title,
    body = build_body(),
    open = not trace.collapsed,
    margin = 0,
    on_open = lazy and function(body)
      if not lazy then
        return
      end
      local new_kids, err = sess:lazyTraceChildrenToInteractive(lazy)
      children_err = err
      children = { strict = new_kids }
      lazy = nil
      body:set_children(build_body())
    end or nil,
  }

  return Element:new {
    text = (' '):rep(trace.indent),
    children = { section },
  }
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
    return InteractiveCode(...)
  end,

  goal = function(_, ...)
    return InteractiveGoal(...)
  end,

  ---@param embed WidgetEmbed
  ---@param sess ReconnectingSubsession
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
  ---@param sess ReconnectingSubsession
  trace = function(_, trace, sess, parent_cls)
    return render_trace(trace, sess, parent_cls, interactive_diagnostic.TaggedTextMsgEmbed)
  end,
})

---@class TaggedText.MsgEmbed: TaggedText
---@field append? TaggedText.MsgEmbed[]
---@field tag? {[1]: MsgEmbed, [2]: ''} the second field happens to always the empty string

interactive_diagnostic.TaggedTextMsgEmbed = TaggedText('MsgEmbed', function(msg_embed, _, ...)
  return interactive_diagnostic.MsgEmbed(msg_embed, ...)
end)

---Check whether a TaggedText<MsgEmbed> contains any trace embeds.
---@param msg TaggedText.MsgEmbed
---@return boolean
interactive_diagnostic.is_trace_message = interactive_diagnostic.TaggedTextMsgEmbed:match {
  text = function()
    return false
  end,
  append = function(children)
    return vim.iter(children):any(interactive_diagnostic.is_trace_message)
  end,
  tag = function(tag)
    return type(tag[1]) == 'table' and tag[1].trace ~= nil
  end,
}

---@alias HighlightedMsgEmbed MsgEmbedExpr | MsgEmbedGoal | MsgEmbedWidget | MsgEmbedTrace | '"highlighted"'

---Dispatch a MsgEmbed using the highlighted variants of each renderer.
local render_highlighted_msg_embed = interactive_diagnostic.MsgEmbed:match {
  expr = function(expr, sess)
    return InteractiveCode.Highlighted(expr, sess)
  end,

  goal = function(goal, sess)
    return InteractiveGoal(goal, sess)
  end,

  ---@param embed WidgetEmbed
  ---@param sess ReconnectingSubsession
  widget = function(embed, sess)
    local widget = widgets.render(embed.wi, sess)
    if widget then
      return widget
    end

    log:debug {
      message = 'Widget rendering failed, falling back to the `alt` widget.',
      widget = embed,
    }
    return interactive_diagnostic.TaggedTextHighlightedMsgEmbed(embed.alt, sess)
  end,

  ---@param trace TraceEmbed
  ---@param sess ReconnectingSubsession
  trace = function(trace, sess, parent_cls)
    return render_trace(
      trace,
      sess,
      parent_cls,
      interactive_diagnostic.TaggedTextHighlightedMsgEmbed
    )
  end,
}

---Render a TaggedText<HighlightedMsgEmbed> returned by the trace search RPC.
---
---Like TaggedTextMsgEmbed but additionally handles the 'highlighted' tag
---variant (renders children with leanInfoHighlighted).
interactive_diagnostic.TaggedTextHighlightedMsgEmbed = TaggedText(
  'HighlightedMsgEmbed',
  function(embed, tag, sess, parent_cls)
    if embed == 'highlighted' then
      local child = interactive_diagnostic.TaggedTextHighlightedMsgEmbed(tag, sess, parent_cls)
      child.hlgroups = { 'leanInfoHighlighted' }
      return child
    end

    return render_highlighted_msg_embed(embed, sess, parent_cls)
  end
)

return interactive_diagnostic
