local Element = require('lean.tui').Element

vim.api.nvim_set_hl(0, 'tui.table.header', { default = true, bold = true })
vim.api.nvim_set_hl(0, 'tui.table.separator', { default = true, link = 'WinSeparator' })

local Table = {}

-- Element:foldable prefixes titles with a 2-char arrow (▶ /▼ ).
local FOLD_PREFIX_WIDTH = vim.fn.strdisplaywidth '▶ '

---Build the padded cell elements for a single row.
---@param elements Element[] cell Elements
---@param col_widths integer[] column widths
---@param widths integer[] per-cell display widths
---@param indent integer extra spaces to prepend to the first cell
---@return Element
local function render_cells(elements, col_widths, widths, indent)
  local cell_elements = {}
  for c, cell in ipairs(elements) do
    local pad = string.rep(' ', (col_widths[c] or 0) - widths[c])
    local cell_content
    if c == 1 and indent > 0 then
      cell_content = Element:new {
        children = { Element.text(string.rep(' ', indent)), cell, Element:new { text = pad } },
      }
    else
      cell_content = Element:new { children = { cell, Element:new { text = pad } } }
    end
    table.insert(cell_elements, cell_content)
    if c < #elements then
      table.insert(cell_elements, Element.text ' │ ')
    end
  end
  return Element:new { children = cell_elements }
end

---Render a plain row into result Elements.
local function render_row(elements, col_widths, widths, max_prefix)
  return { render_cells(elements, col_widths, widths, max_prefix) }
end

---Render a header row and its separator into result Elements.
local function render_header(elements, col_widths, widths, max_prefix)
  local sep_parts = {}
  for c, w in ipairs(col_widths) do
    local extra = c == 1 and max_prefix or 0
    table.insert(sep_parts, string.rep('─', w + extra))
    if c < #col_widths then
      table.insert(sep_parts, '─┼─')
    end
  end
  return {
    Element:new {
      hlgroups = { 'tui.table.header' },
      children = { render_cells(elements, col_widths, widths, max_prefix) },
    },
    Element:new { text = table.concat(sep_parts), hlgroups = { 'tui.table.separator' } },
  }
end

---A regular table row.
---@param cells Element[]
function Table.row(cells)
  return { cells = cells, prefix_width = 0, render = render_row }
end

---A header row, rendered with a separator line beneath it.
---@param cells Element[]
function Table.header(cells)
  return { cells = cells, prefix_width = 0, render = render_header }
end

---@class TableFoldableOpts
---@field cells Element[] the parent row cells
---@field children table[] rows to show when expanded (any row type, including nested foldable)
---@field open? boolean initial state (default false)
---@field on_open? fun() called when the fold is opened
---@field on_close? fun() called when the fold is closed

---A foldable table row with child rows that expand/collapse on click.
---Child rows are rendered independently when expanded; they share
---column widths with the parent table but are not pre-measured.
---@param opts TableFoldableOpts
function Table.foldable(opts)
  return {
    cells = opts.cells,
    prefix_width = FOLD_PREFIX_WIDTH,
    render = function(elements, col_widths, widths, max_prefix)
      return {
        Element:foldable {
          title = render_cells(elements, col_widths, widths, 0),
          body = { Table.render(opts.children, col_widths, max_prefix) },
          open = opts.open or false,
          on_open = opts.on_open,
          on_close = opts.on_close,
          margin = 0,
        },
      }
    end,
  }
end

---Build a table Element from rows.
---
---Rows are created with `Table.row { ... }`, `Table.header { ... }`,
---or `Table.foldable(cells, children)`.
---Columns are padded to align.
---@param rows table[]
---@param inherited_col_widths? integer[] column widths from a parent table (for nested rendering)
---@param inherited_prefix? integer minimum prefix width from a parent table
---@return Element
function Table.render(rows, inherited_col_widths, inherited_prefix)
  if #rows == 0 then
    return Element:new {}
  end

  -- Compute the max prefix width across all rows so non-prefixed
  -- rows can indent to align with prefixed ones (e.g. foldable arrows).
  local max_prefix = inherited_prefix or 0
  for _, row in ipairs(rows) do
    if row.prefix_width > max_prefix then
      max_prefix = row.prefix_width
    end
  end

  -- Measure column widths from this row set.
  local col_widths = {}
  local cell_widths = {}
  local cells = {}
  for r, row in ipairs(rows) do
    cell_widths[r] = {}
    cells[r] = {}
    for c, cell in ipairs(row.cells) do
      cells[r][c] = cell
      local w = vim.fn.strdisplaywidth(cell:to_string())
      cell_widths[r][c] = w
      col_widths[c] = math.max(col_widths[c] or 0, w)
    end
  end

  -- Inherit wider column widths from parent table if provided.
  if inherited_col_widths then
    for c, w in ipairs(inherited_col_widths) do
      col_widths[c] = math.max(col_widths[c] or 0, w)
    end
  end

  -- Build result rows.
  local result_rows = {}
  for r, row in ipairs(rows) do
    vim.list_extend(result_rows, row.render(cells[r], col_widths, cell_widths[r], max_prefix))
  end

  return Element:new {
    is_block = true,
    children = { Element:concat(result_rows, '\n') },
  }
end

return Table
