local Element = require('lean.tui').Element

local html = {}

vim.api.nvim_set_hl(0, 'tui.html.b', { bold = true })
vim.api.nvim_set_hl(0, 'tui.html.i', { italic = true })
vim.api.nvim_set_hl(0, 'tui.html.summary', { link = 'Title' })
vim.api.nvim_set_hl(0, 'tui.html.unsupported', { link = 'ErrorMsg' })

html.Tag = vim.defaulttable(function(tag)
  return function(children)
    return Element:new {
      hlgroup = 'tui.html.unsupported',
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
    hlgroup = 'tui.html.summary',
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
  return Element:new { hlgroup = 'tui.html.b', children = children }
end

---Render italic text.
function html.Tag.i(children)
  return Element:new { hlgroup = 'tui.html.i', children = children }
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

return html
