local inductive = require 'std.inductive'

local Element = require('lean.tui').Element
local InteractiveCode = require 'lean.widget.interactive_code'
local MakeEditLink = require 'proofwidgets.make_edit_link'
local Table = require 'tui.table'
local tui_html = require 'tui.html'
local Tag = tui_html.Tag

---@class HtmlElement
---@field element { [1]: string, [2]: [string, any][], [3]: Html[] }

---@class HtmlText
---@field text string

---@class HtmlComponent
---@field component { [1]: string, [2]: string, [3]:  any, [4]: Html[] }

---Render a `<details>` element with collapsible content.
---
---Handled here rather than in Tag because the dispatcher needs to
---identify the `<summary>` child from the raw Html tree (by tag name)
---before rendering, rather than relying on injected markers on Elements.
---@param self fun(html: Html, ctx: RenderContext, opts?: table): Element
---@param value { [1]: string, [2]: [string, any][], [3]: Html[] }
---@param ctx RenderContext
---@param opts? table
---@return Element
local function render_details(self, value, ctx, opts)
  local _, raw_attrs, children = unpack(value)

  local initially_open = vim.iter(raw_attrs):any(function(attr)
    return attr[1] == 'open'
  end)

  local summary_children
  local body_elements = {}
  for _, child in ipairs(children) do
    if
      not summary_children
      and type(child) == 'table'
      and child.element
      and child.element[1] == 'summary'
    then
      summary_children = vim
        .iter(child.element[3])
        :map(function(c)
          return self(c, ctx, opts)
        end)
        :totable()
    else
      table.insert(body_elements, self(child, ctx, opts))
    end
  end

  return Element:foldable {
    title = Element:new {
      hlgroups = { 'tui.html.summary' },
      children = summary_children or { Element.text 'Details' },
    },
    body = body_elements,
    open = initially_open,
    gap = 1,
  }
end

local SECTION_ROW_TYPES = {
  thead = Table.header,
  tbody = Table.row,
  tfoot = Table.row,
}

---Render the cells of a `<tr>` element.
---@param self fun(html: Html, ctx: RenderContext, opts?: table): Element
---@param tr_children Html[]
---@param ctx RenderContext
---@param opts? table
---@return Element[]
local function render_tr_cells(self, tr_children, ctx, opts)
  local cells = {}
  for _, cell_html in ipairs(tr_children) do
    table.insert(cells, self(cell_html, ctx, opts))
  end
  return cells
end

---Collect rows from a raw Html table tree.
---
---Walks the Html children of a `<table>`, descending through
---`<thead>`/`<tbody>`/`<tfoot>` wrappers to find `<tr>` elements,
---then renders each cell into `Table.header` or `Table.row` objects.
---@param self fun(html: Html, ctx: RenderContext, opts?: table): Element
---@param table_children Html[]
---@param ctx RenderContext
---@param opts? table
---@return (TableRow|TableHeader)[]
local function collect_table_rows(self, table_children, ctx, opts)
  local rows = {}
  for _, child in ipairs(table_children) do
    if type(child) == 'table' and child.element then
      local tag = child.element[1]
      local RowType = SECTION_ROW_TYPES[tag]
      if RowType then
        for _, section_child in ipairs(child.element[3]) do
          if
            type(section_child) == 'table'
            and section_child.element
            and section_child.element[1] == 'tr'
          then
            table.insert(rows, RowType(render_tr_cells(self, section_child.element[3], ctx, opts)))
          end
        end
      elseif tag == 'tr' then
        table.insert(rows, Table.row(render_tr_cells(self, child.element[3], ctx, opts)))
      end
    end
  end
  return rows
end

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
          Element.text '\n',
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
  ---@param opts? { in_pre: boolean, list_depth: integer }
  ---@return Element
  element = function(self, value, ctx, opts)
    local tag, raw_attrs, children = unpack(value)

    local attrs = {}
    for _, attr in ipairs(raw_attrs) do
      attrs[attr[1]] = attr[2]
    end

    -- Normalize CSS string styles to tables so downstream code only
    -- handles one format.
    if type(attrs.style) == 'string' then
      attrs.style = tui_html.parse_css(attrs.style)
    end

    -- Elements with display:none or visibility:hidden render as empty.
    if attrs.style and tui_html.is_hidden(attrs.style) then
      return Element:new {}
    end

    local result

    -- Structural tags handled here rather than in individual Tag handlers,
    -- because they need access to the raw Html tree.
    if tag == 'svg' then
      result = Tag.svg(value)
    elseif tag == 'details' then
      result = Element:new {
        is_block = true,
        margin = 1,
        children = { render_details(self, value, ctx, opts) },
      }
    elseif tag == 'table' then
      local rows = collect_table_rows(self, children, ctx, opts)
      result = Element:new {
        is_block = true,
        margin = 1,
        children = { Table.render(rows) },
      }
    else
      if tag == 'pre' then
        opts = vim.tbl_extend('force', opts or {}, { in_pre = true })
      end

      -- CSS white-space: pre/pre-wrap also preserves whitespace,
      -- matching how the <pre> tag works.
      if attrs.style and not (opts and opts.in_pre) then
        local ws = attrs.style['white-space'] or attrs.style.whiteSpace
        if ws == 'pre' or ws == 'pre-wrap' or ws == 'pre-line' then
          opts = vim.tbl_extend('force', opts or {}, { in_pre = true })
        end
      end

      local current_opts = opts
      if tag == 'ul' or tag == 'ol' then
        -- Children of this list see an incremented depth (for nested lists),
        -- but the current list's tag handler uses the current depth.
        opts = vim.tbl_extend('force', opts or {}, {
          list_depth = ((opts and opts.list_depth) or 0) + 1,
        })
      end
      local elements = vim
        .iter(children)
        :map(function(child)
          return self(child, ctx, opts)
        end)
        :totable()
      result = Tag[tag](elements, attrs, current_opts)
    end

    -- Apply inline styles from any element's style attribute.
    result = tui_html._styled(result, attrs)

    -- Wire the title attribute to a tooltip.
    if attrs.title then
      result:add_tooltip(Element:new { text = attrs.title })
    end

    return result
  end,
})

return Html
