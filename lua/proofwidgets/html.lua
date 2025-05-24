local inductive = require 'std.inductive'

local Element = require('lean.tui').Element
local InteractiveCode = require 'lean.widget.interactive_code'
local MakeEditLink = require 'proofwidgets.make_edit_link'
local Tag = require('tui.html').Tag

---@class HtmlElement
---@field element { [1]: string, [2]: [string, any][], [3]: Html[] }

---@class HtmlText
---@field text string

---@class HtmlComponent
---@field component { [1]: string, [2]: string, [3]:  any, [4]: Html[] }

---@alias Html HtmlElement | HtmlText | HtmlComponent
local Html = inductive('Html', {
  ---@param text string
  ---@return Element
  text = function(_, text)
    return Element:new { text = text }
  end,

  ---@param value { [1]: string, [2]: string, [3]:  any, [4]: Html[] }
  ---@param ctx RenderContext
  ---@return Element
  component = function(self, value, ctx)
    local _, _, props, more = unpack(value)
    -- TODO: This should render export through our own bypassing logic,
    --       but we only have a hash here, not the ID...

    local children = vim
      .iter(more)
      :map(function(child)
        return self(child, ctx)
      end)
      :totable()

    if props.fmt then
      return Element:new {
        children = {
          InteractiveCode(props.fmt, ctx:subsession()),
          Element:new { children = children },
        },
      }
    elseif props.edit then
      return MakeEditLink(props, children, ctx)
    end

    return Element:new {
      text = vim.inspect(props),
      children = children,
    }
  end,

  ---@param value { [1]: string, [2]: [string, any][], [3]: Html[] }
  ---@param ctx RenderContext
  ---@return Element
  element = function(self, value, ctx)
    local tag, _, children = unpack(value)
    local elements = vim
      .iter(children)
      :map(function(child)
        return self(child, ctx)
      end)
      :totable()
    return Tag[tag](elements)
  end,
})

return Html
