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
    elseif props.contents and type(props.contents) == 'string' then
      return Element:new { text = props.contents, children = children }
    elseif props.expr then
      local response, rpc_err = ctx:rpc_call('ProofWidgets.ppExprTagged', { expr = props.expr })
      if rpc_err then
        return rpc_err
      end
      if response then
        return Element:new {
          children = {
            InteractiveCode(response, ctx:subsession()),
            Element:new { children = children },
          },
        }
      end
    elseif props.msg then
      local interactive_diagnostic = require 'lean.widget.interactive_diagnostic'
      local sess = ctx:subsession()
      local response, err = sess:msgToInteractive(props.msg, 0)
      if err then
        return Element:new { text = vim.inspect(err), children = children }
      end
      return Element:new {
        children = {
          interactive_diagnostic.TaggedTextMsgEmbed(response, sess),
          Element:new { children = children },
        },
      }
    elseif props.summary and props.filtered then
      local content = props.initiallyFiltered ~= false and props.filtered or props.all
      return Element:new {
        children = {
          self(props.summary, ctx, opts),
          Element:new { text = '\n' },
          self(content, ctx, opts),
          Element:new { children = children },
        },
      }
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
    local tag, raw_attrs, children = unpack(value)
    if tag == 'svg' then
      return Tag.svg(value)
    end
    if tag == 'pre' then
      opts = { in_pre = true }
    end
    local attrs = {}
    for _, attr in ipairs(raw_attrs) do
      attrs[attr[1]] = tostring(attr[2])
    end
    local elements = vim
      .iter(children)
      :map(function(child)
        return self(child, ctx, opts)
      end)
      :totable()
    return Tag[tag](elements, attrs)
  end,
})

return Html
