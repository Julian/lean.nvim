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

---A `<summary>` tag (within `details`).
---
---When rendered outside a `<details>`, this is just a titled block.
---The `<details>` handler in the dispatcher is responsible for making
---summary elements collapsible.
function html.Tag.summary(children)
  return Element:new {
    text = '▼ ',
    hlgroups = { 'tui.html.summary' },
    children = children,
  }
end

---Render a block-level `<div>` element.
function html.Tag.div(children, attrs)
  return html._styled(
    Element:new {
      text = '\n',
      children = {
        Element:new { children = children },
      },
    },
    attrs
  )
end

---Render an inline `<span>` element.
function html.Tag.span(children, attrs)
  return html._styled(Element:new { children = children }, attrs)
end

---Render a `<p>` paragraph.
---
---In a browser, `<p>` is a block element with vertical margin, but in
---practice ProofWidgets wraps list item content in `<p>` tags, so we
---render it as a plain container to avoid unwanted extra whitespace.
function html.Tag.p(children, attrs)
  return html._styled(Element:new { children = children }, attrs)
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

---Render a horizontal rule.
function html.Tag.hr()
  return Element:new {
    text = '\n' .. string.rep('─', 40) .. '\n',
    hlgroups = { 'tui.html.hr' },
  }
end

---Render heading tags.
for level = 1, 6 do
  html.Tag['h' .. level] = function(children)
    return Element:new {
      text = '\n',
      hlgroups = { 'tui.html.h' .. level },
      children = {
        Element:new { children = children },
        Element:new { text = '\n' },
      },
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

---Render an unordered list.
---@param children Element[]
---@param _attrs table<string, any>
---@param opts? { list_depth: integer }
function html.Tag.ul(children, _attrs, opts)
  local depth = (opts and opts.list_depth or 0)
  local indent = string.rep('  ', depth)
  local items = vim
    .iter(children)
    :map(function(child)
      return Element:new { text = indent .. '• ', children = { child } }
    end)
    :totable()
  return Element:new {
    text = '\n',
    children = { Element:concat(items, '\n') },
  }
end

---Render an ordered list.
---@param children Element[]
---@param _attrs table<string, any>
---@param opts? { list_depth: integer }
function html.Tag.ol(children, _attrs, opts)
  local depth = (opts and opts.list_depth or 0)
  local indent = string.rep('  ', depth)
  local items = vim
    .iter(children)
    :enumerate()
    :map(function(i, child)
      return Element:new { text = indent .. tostring(i) .. '. ', children = { child } }
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
      table.insert(result_rows, Element:new { text = table.concat(sep_parts) })
    end
  end

  return Element:new {
    text = '\n',
    children = { Element:concat(result_rows, '\n') },
  }
end

---Render an `<img>` element using the Kitty graphics protocol.
---@param _children Element[] (unused, img is a void element)
---@param attrs table<string, any>
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
function html.Tag.pre(children)
  return Element:new {
    text = '\n',
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
  elseif normalized == 'font-weight' and value == 'bold' then
    hl.bold = true
  elseif normalized == 'font-style' and value == 'italic' then
    hl.italic = true
  elseif normalized == 'text-decoration' then
    if value:find 'underline' then
      hl.underline = true
    end
    if value:find 'line%-through' then
      hl.strikethrough = true
    end
  end
end

---Parse a style value (CSS string or JSON-style table) into Neovim
---highlight attributes.
---@param style string|table
---@return table<string, any>?
local function parse_style(style)
  local hl = {}
  if type(style) == 'table' then
    for prop, value in pairs(style) do
      if type(value) == 'string' then
        apply_css_prop(hl, prop, value)
      end
    end
  elseif type(style) == 'string' then
    for prop, value in style:gmatch '([%w-]+)%s*:%s*([^;]+)' do
      apply_css_prop(hl, vim.trim(prop), vim.trim(value))
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

---Apply inline style from attrs to an element, returning a possibly-wrapped element.
---@param element Element
---@param attrs? table<string, any>
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
  element.hlgroups = { hlgroup }
  return element
end

return html
