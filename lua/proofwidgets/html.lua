local inductive = require 'std.inductive'

local Element = require('lean.tui').Element
local InteractiveCode = require 'lean.widget.interactive_code'

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
  ---@return Element
  component = function(self, value, sess)
    local _, _, props, children = unpack(value)
    -- TODO: This should render export through our own bypassing logic,
    --       but we only have a hash here, not the ID...
    local elements = vim
      .iter(children)
      :map(function(child)
        return self(child, sess)
      end)
      :totable()
    return Element:new {
      children = {
        InteractiveCode(props.fmt, sess),
        Element:new { children = elements },
      },
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
    if tag == 'span' then
      return Element:new { children = elements }
    end
    return Element:new { text = ('<%s>'):format(tag), children = elements }
  end,
})

return Html
