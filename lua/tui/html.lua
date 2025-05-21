local Element = require('lean.tui').Element

local html = {}

vim.api.nvim_set_hl(0, 'tuiHTMLUnsupported', { link = 'ErrorMsg' })

html.Tag = vim.defaulttable(function(tag)
  return function(children)
    return Element:new {
      hlgroup = 'tuiHTMLUnsupported',
      text = ('<%s>'):format(tag),
      children = children,
    }
  end
end)

---A `<details>` tag.
function html.Tag.details(children)
  -- TODO: make me foldable when we support that
  return Element:new { children = children }
end

---A `<summary>` tag (within `details`).
function html.Tag.summary(children)
  return Element:new { children = children }
end

---Just render the children, as we don't (yet?) support passing through styles.
function html.Tag.div(children)
  return Element:new { children = children }
end

---Just render the children, as we don't (yet?) support passing through styles.
function html.Tag.span(children)
  return Element:new { children = children }
end

return html
