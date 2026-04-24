local Element = require('lean.tui').Element
local image = require 'tui.image'
local kitty = require 'kitty'

local html = {}

vim.api.nvim_set_hl(0, 'tui.html.b', { default = true, bold = true })
vim.api.nvim_set_hl(0, 'tui.html.i', { default = true, italic = true })
vim.api.nvim_set_hl(0, 'tui.html.code', { default = true, link = '@markup.raw' })
vim.api.nvim_set_hl(0, 'tui.html.hr', { default = true, link = 'WinSeparator' })
vim.api.nvim_set_hl(0, 'tui.html.h1', { default = true, link = 'Title' })
vim.api.nvim_set_hl(0, 'tui.html.h2', { default = true, link = '@markup.heading.2' })
vim.api.nvim_set_hl(0, 'tui.html.h3', { default = true, link = '@markup.heading.3' })
vim.api.nvim_set_hl(0, 'tui.html.h4', { default = true, link = '@markup.heading.4' })
vim.api.nvim_set_hl(0, 'tui.html.h5', { default = true, link = '@markup.heading.5' })
vim.api.nvim_set_hl(0, 'tui.html.h6', { default = true, link = '@markup.heading.6' })
vim.api.nvim_set_hl(0, 'tui.html.del', { default = true, strikethrough = true })
vim.api.nvim_set_hl(0, 'tui.html.u', { default = true, underline = true })
vim.api.nvim_set_hl(0, 'tui.html.mark', { default = true, link = 'Search' })
vim.api.nvim_set_hl(0, 'tui.html.blockquote', { default = true, link = 'Comment' })
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

---A `<summary>` tag rendered outside `<details>`.
---
---Within `<details>`, the dispatcher builds a foldable `Element:foldable`
---directly, bypassing this handler.
function html.Tag.summary(children)
  return Element:new {
    hlgroups = { 'tui.html.summary' },
    children = children,
  }
end

---Render a block-level `<div>` element.
function html.Tag.div(children)
  return Element:new { is_block = true, children = children }
end

---Render an inline `<span>` element.
function html.Tag.span(children)
  return Element:new { children = children }
end

---Render a `<p>` paragraph as a block element.
function html.Tag.p(children)
  return Element:new { is_block = true, children = children }
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

---Render inline code.
function html.Tag.code(children)
  return Element:new { hlgroups = { 'tui.html.code' }, children = children }
end

---Render deleted/strikethrough text.
function html.Tag.del(children)
  return Element:new { hlgroups = { 'tui.html.del' }, children = children }
end

---An alias for `<del>`.
html.Tag.s = html.Tag.del

---Render underlined text.
function html.Tag.u(children)
  return Element:new { hlgroups = { 'tui.html.u' }, children = children }
end

---An alias for `<u>`.
html.Tag.ins = html.Tag.u

---Render highlighted/marked text.
function html.Tag.mark(children)
  return Element:new { hlgroups = { 'tui.html.mark' }, children = children }
end

---Render a blockquote as an indented block.
---
---Uses `line_prefix` so every rendered line within the blockquote gets
---the `│ ` bar, matching how browsers render a left border on the block.
function html.Tag.blockquote(children)
  return Element:new {
    is_block = true,
    line_prefix = { text = '│ ', hlgroup = 'tui.html.blockquote' },
    children = children,
  }
end

---Render subscript text with Unicode sub-parentheses: ₍text₎
function html.Tag.sub(children)
  table.insert(children, 1, Element:new { text = '₍' })
  table.insert(children, Element:new { text = '₎' })
  return Element:new { children = children }
end

---Render superscript text with Unicode super-parentheses: ⁽text⁾
function html.Tag.sup(children)
  table.insert(children, 1, Element:new { text = '⁽' })
  table.insert(children, Element:new { text = '⁾' })
  return Element:new { children = children }
end

---`<style>` content is CSS for the browser — hide it in the TUI.
function html.Tag.style()
  return Element:new {}
end

---`<script>` content should never be rendered as visible text.
function html.Tag.script()
  return Element:new {}
end

---Render a horizontal rule.
function html.Tag.hr()
  return Element:new {
    is_block = true,
    text = string.rep('─', 40),
    hlgroups = { 'tui.html.hr' },
  }
end

---Render heading tags.
for level = 1, 6 do
  html.Tag['h' .. level] = function(children)
    return Element:new {
      is_block = true,
      hlgroups = { 'tui.html.h' .. level },
      children = children,
    }
  end
end

---Render an `<a>` tag as a clickable link.
---@param children Element[]
---@param attrs table<string, any>
function html.Tag.a(children, attrs)
  if attrs and attrs.href then
    return Element.link {
      children = children,
      action = function()
        vim.ui.open(attrs.href)
      end,
    }
  end
  return Element:new { children = children }
end

---Clear `is_block` on the first block element in a tree.
---
---In a browser, list bullets sit in the margin and align with the first
---baseline regardless of block children.  Since our bullets are inline
---text, a block child would force a newline after the bullet.  Clearing
---`is_block` on the leading block element chain prevents that.
---@param element Element
local function clear_first_block(element)
  if element.is_block then
    element.is_block = false
  end
  local child = element:children():next()
  if child then
    clear_first_block(child)
  end
end

-- Browsers cycle bullet markers by list depth: disc → circle → square.
local ul_markers = { '• ', '◦ ', '▪ ' }

---Render an unordered list.
---@param children Element[]
---@param _attrs table<string, any>
---@param opts? { list_depth: integer }
function html.Tag.ul(children, _attrs, opts)
  local depth = (opts and opts.list_depth or 0)
  local indent = string.rep('  ', depth)
  local marker = ul_markers[depth % #ul_markers + 1]
  local items = vim
    .iter(children)
    :map(function(child)
      clear_first_block(child)
      return Element:new { text = indent .. marker, children = { child } }
    end)
    :totable()
  return Element:new {
    is_block = true,
    children = { Element:concat(items, '\n') },
  }
end

---Render an ordered list.
---@param children Element[]
---@param attrs? table<string, any>
---@param opts? { list_depth: integer }
function html.Tag.ol(children, attrs, opts)
  local depth = (opts and opts.list_depth or 0)
  local indent = string.rep('  ', depth)
  local start = (attrs and attrs.start and tonumber(attrs.start) or 1) - 1
  local items = vim
    .iter(children)
    :enumerate()
    :map(function(i, child)
      clear_first_block(child)
      return Element:new { text = indent .. tostring(start + i) .. '. ', children = { child } }
    end)
    :totable()
  return Element:new {
    is_block = true,
    children = { Element:concat(items, '\n') },
  }
end

---Render a list item.
function html.Tag.li(children)
  return Element:new { children = children }
end

---Render a table data cell.
function html.Tag.td(children)
  return Element:new { children = children }
end

---Render a table header cell.
function html.Tag.th(children)
  return Element:new { hlgroups = { 'tui.html.b' }, children = children }
end

---Build a table Element from pre-collected row data.
---
---This is called by the dispatcher which processes the raw Html tree
---to extract rows and cells before rendering, rather than relying on
---individual tag handlers for structural table elements.
---@param rows { cells: Element[], is_header: boolean }[]
---@return Element
function html.render_table(rows)
  if #rows == 0 then
    return Element:new {}
  end

  -- Measure column widths from rendered text.
  local col_widths = {}
  for _, row in ipairs(rows) do
    for c, cell in ipairs(row.cells) do
      local text = cell:to_string()
      local w = vim.fn.strdisplaywidth(text)
      col_widths[c] = math.max(col_widths[c] or 0, w)
    end
  end

  -- Build padded rows.
  local result_rows = {}
  for _, row in ipairs(rows) do
    local cell_elements = {}
    for c, cell in ipairs(row.cells) do
      local text = cell:to_string()
      local pad = string.rep(' ', (col_widths[c] or 0) - vim.fn.strdisplaywidth(text))
      table.insert(
        cell_elements,
        Element:new {
          children = { cell, Element:new { text = pad } },
        }
      )
      if c < #row.cells then
        table.insert(cell_elements, Element:new { text = ' │ ' })
      end
    end
    table.insert(result_rows, Element:new { children = cell_elements })

    if row.is_header then
      local sep_parts = {}
      for c, w in ipairs(col_widths) do
        table.insert(sep_parts, string.rep('─', w))
        if c < #col_widths then
          table.insert(sep_parts, '─┼─')
        end
      end
      table.insert(
        result_rows,
        Element:new { text = table.concat(sep_parts), hlgroups = { 'tui.html.hr' } }
      )
    end
  end

  return Element:new {
    is_block = true,
    children = { Element:concat(result_rows, '\n') },
  }
end

---Render an `<img>` element using the Kitty graphics protocol.
---
---Falls back to `alt` text (like a browser) when the image cannot be
---decoded, or to a placeholder when neither is available.
---@param _children Element[] (unused, img is a void element)
---@param attrs table<string, any>
function html.Tag.img(_children, attrs)
  if not attrs.src then
    return Element:new {
      hlgroups = { 'Comment' },
      text = attrs.alt or '[img: no src]',
    }
  end

  local decoded, reason = image.decode(attrs.src)
  if not decoded then
    return Element:new {
      hlgroups = { 'Comment' },
      text = attrs.alt or reason,
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

---Render an `<svg>` element via resvg and the Kitty graphics protocol.
---
---Unlike other tag handlers, this receives the raw HtmlElement value triple
---(from the dispatcher), not pre-converted Element children, because we need
---the original tree to serialize back to an SVG string.
---@param value { [1]: string, [2]: [string, any][], [3]: table[] }
function html.Tag.svg(value)
  local svg = require 'tui.svg'
  if not svg.available() then
    return Element:new {
      hlgroups = { 'Comment' },
      text = '[SVG: install libresvg to render]',
    }
  end

  local ok, result = pcall(function()
    local svg_string = svg.serialize(value)
    local pixels, w, h = svg.rasterize(svg_string)
    local overlay = image.from_pixels(svg_string, pixels, w, h)
    local rows = kitty.rows_for_height(overlay.height)
    return Element:new {
      text = string.rep('\n', rows - 1),
      overlay = overlay,
    }
  end)
  if ok then
    return result
  end

  return Element:new {
    hlgroups = { 'WarningMsg' },
    text = '[SVG render failed: ' .. tostring(result) .. ']',
  }
end

---Render preformatted text as a block element.
---
---Keeps a trailing newline since `<pre>` may be followed by inline
---content within the same parent (e.g. `<span><pre>…</pre>text</span>`).
function html.Tag.pre(children)
  return Element:new {
    is_block = true,
    children = {
      Element:new { children = children },
      Element:new { text = '\n' },
    },
  }
end

---Apply a single CSS property to a Neovim highlight attribute table.
---
---Handles both kebab-case (`background-color`) and camelCase
---(`backgroundColor`) property names.
---@param hl table<string, any>
---@param prop string
---@param value string
local function apply_css_prop(hl, prop, value)
  -- Normalize camelCase → kebab-case for matching.
  local normalized = prop:gsub('(%u)', function(c)
    return '-' .. c:lower()
  end)
  if normalized == 'color' then
    hl.fg = value
  elseif normalized == 'background-color' or normalized == 'background' then
    hl.bg = value
  elseif normalized == 'font-weight' then
    -- CSS bold is the keyword "bold" or a numeric weight >= 700.
    local n = tonumber(value)
    if value == 'bold' or value == 'bolder' or (n and n >= 700) then
      hl.bold = true
    end
  elseif normalized == 'font-style' and value == 'italic' then
    hl.italic = true
  elseif normalized == 'text-decoration' or normalized == 'text-decoration-line' then
    if value:find 'underline' then
      hl.underline = true
    end
    if value:find 'line%-through' then
      hl.strikethrough = true
    end
  end
end

---Parse a CSS string into a property table.
---
---Normalizes the string format (`"color: red; font-weight: bold"`) into
---the same table format (`{ color = "red", ["font-weight"] = "bold" }`)
---that JSON-style attributes already use, so all downstream code only
---needs to handle tables.
---@param css string
---@return table<string, string>
function html.parse_css(css)
  local props = {}
  for prop, value in css:gmatch '([%w-]+)%s*:%s*([^;]+)' do
    props[vim.trim(prop)] = vim.trim(value)
  end
  return props
end

---Parse a style table into Neovim highlight attributes.
---@param style table<string, any>
---@return table<string, any>?
local function parse_style(style)
  local hl = {}
  for prop, value in pairs(style) do
    if type(value) == 'string' then
      apply_css_prop(hl, prop, value)
    end
  end
  if next(hl) == nil then
    return nil
  end
  return hl
end

-- Cache from serialized highlight attrs → hlgroup name, so we don't
-- create unbounded highlight groups for repeated styles.
local style_hlgroups = {} ---@type table<string, string>
local style_hl_counter = 0

---Check whether a style table hides the element (`display: none`,
---`visibility: hidden`, or `opacity: 0`).
---@param style table<string, any>
---@return boolean
function html.is_hidden(style)
  if style.display == 'none' then
    return true
  end
  if style.visibility == 'hidden' then
    return true
  end
  local opacity = style.opacity
  if opacity == '0' or opacity == 0 then
    return true
  end
  return false
end

---Apply inline style from attrs to an element, returning a possibly-wrapped element.
---
---Composes with any highlight groups the element already carries (e.g.
---from its tag handler), so `<b style="color: red">` gets both bold and
---the color.
---
---Expects `attrs.style` to already be a table (normalized by the
---dispatcher via `html.parse_css`).
---@param element Element
---@param attrs? { style?: table<string, any> }
---@return Element
function html._styled(element, attrs)
  if not attrs or not attrs.style then
    return element
  end

  local hl = parse_style(attrs.style)
  if not hl then
    return element
  end

  local cache_key = vim.inspect(hl)
  local hlgroup = style_hlgroups[cache_key]
  if not hlgroup then
    style_hl_counter = style_hl_counter + 1
    hlgroup = 'tui.html.style.' .. style_hl_counter
    vim.api.nvim_set_hl(0, hlgroup, hl)
    style_hlgroups[cache_key] = hlgroup
  end
  if element.hlgroups then
    table.insert(element.hlgroups, hlgroup)
  else
    element.hlgroups = { hlgroup }
  end
  return element
end

return html
