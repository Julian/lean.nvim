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
  ---@param _ctx RenderContext
  ---@param opts? { in_pre: boolean }
  ---@return Element
  text = function(_, text, _ctx, opts)
    if not opts or not opts.in_pre then
      text = text:gsub('%s+', ' ')
    end
    return Element:new { text = text }
  end,

  ---@param value { [1]: string, [2]: string, [3]:  any, [4]: Html[] }
  ---@param ctx RenderContext
  ---@param opts? { in_pre: boolean }
  ---@return Element
  component = function(self, value, ctx, opts)
    local _, _, props, more = unpack(value)
    -- TODO: This should render export through our own bypassing logic,
    --       but we only have a hash here, not the ID...

    local children = vim
      .iter(more)
      :map(function(child)
        return self(child, ctx, opts)
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
    elseif props.state and props.cancelTk then
      local RefreshComponent = require 'lean.widgets.ProofWidgets.RefreshComponent'
      return RefreshComponent(ctx, props)
    end

    return Element:new {
      text = vim.inspect(props),
      children = children,
    }
  end,

  ---@param value { [1]: string, [2]: [string, any][], [3]: Html[] }
  ---@param ctx RenderContext
  ---@param opts? { in_pre: boolean }
  ---@return Element
  element = function(self, value, ctx, opts)
    local tag, _, children = unpack(value)
    if tag == 'pre' then
      opts = { in_pre = true }
    end
    local elements = vim
      .iter(children)
      :map(function(child)
        return self(child, ctx, opts)
      end)
      :totable()
    return Tag[tag](elements)
  end,
})

return Html
