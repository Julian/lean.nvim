local Element = require('lean.tui').Element
local image = require 'tui.image'
local kitty = require 'kitty'

local html = {}

vim.api.nvim_set_hl(0, 'tui.html.b', { default = true, bold = true })
vim.api.nvim_set_hl(0, 'tui.html.i', { default = true, italic = true })
vim.api.nvim_set_hl(0, 'tui.html.summary', { default = true, link = 'Title' })
vim.api.nvim_set_hl(0, 'tui.html.unsupported', { default = true, link = 'ErrorMsg' })

html.Tag = vim.defaulttable(function(tag)
  return function(children)
    return Element:new {
      hlgroups = { 'tui.html.unsupported' },
      text = ('<%s>'):format(tag),
      children = children,
    }
  end
end)

---A `<br>` tag.
function html.Tag.br(children)
  return Element:new { text = '\n', children = children }
end

---A `<details>` tag.
function html.Tag.details(children)
  return Element:new { children = children }
end

---A `<summary>` tag (within `details`).
function html.Tag.summary(children)
  return Element:new {
    text = '▼ ',
    hlgroups = { 'tui.html.summary' },
    children = children,
  }
end

---Just render the children, as we don't (yet?) support passing through styles.
function html.Tag.div(children)
  return Element:new {
    text = '\n', -- TODO: clearly this isn't fully "block" element-y
    children = {
      Element:new { children = children },
      -- Element:new { text = '\n' },
    },
  }
end

---Just render the children, as we don't (yet?) support passing through styles.
function html.Tag.span(children)
  return Element:new { children = children }
end

---Render a paragraph.
function html.Tag.p(children)
  return Element:new { children = children }
end

---Render bold text.
function html.Tag.b(children)
  return Element:new { hlgroups = { 'tui.html.b' }, children = children }
end

---Render italic text.
function html.Tag.i(children)
  return Element:new { hlgroups = { 'tui.html.i' }, children = children }
end

---An alias for `<b>`.
html.Tag.strong = html.Tag.b

---An alias for `<i>`.
html.Tag.em = html.Tag.i

---Render an unordered list.
function html.Tag.ul(children)
  local items = vim
    .iter(children)
    :map(function(child)
      return Element:new { text = '• ', children = { child } }
    end)
    :totable()
  return Element:new {
    text = '\n',
    children = { Element:concat(items, '\n') },
  }
end

---Render an ordered list.
function html.Tag.ol(children)
  local items = vim
    .iter(children)
    :enumerate()
    :map(function(i, child)
      return Element:new { text = tostring(i) .. '. ', children = { child } }
    end)
    :totable()
  return Element:new {
    text = '\n',
    children = { Element:concat(items, '\n') },
  }
end

---Render a list item.
function html.Tag.li(children)
  return Element:new { children = children }
end

---Render an `<img>` element using the Kitty graphics protocol.
---@param _children Element[] (unused, img is a void element)
---@param attrs table<string, string>
function html.Tag.img(_children, attrs)
  if not attrs.src then
    return Element:new {
      hlgroups = { 'Comment' },
      text = '[img: no src]',
    }
  end

  local decoded, reason = image.decode(attrs.src)
  if not decoded then
    return Element:new {
      hlgroups = { 'Comment' },
      text = reason,
    }
  end

  local w = (attrs.width and tonumber(attrs.width)) or decoded.width or 200
  local h = (attrs.height and tonumber(attrs.height)) or decoded.height or 200

  local rows = kitty.rows_for_height(h)
  return Element:new {
    text = string.rep('\n', rows - 1),
    overlay = { data = decoded.data, width = w, height = h, format = 100 },
  }
end

---Render preformatted text as a block element.
function html.Tag.pre(children)
  return Element:new {
    text = '\n',
    children = {
      Element:new { children = children },
      Element:new { text = '\n' },
    },
  }
end

return html
