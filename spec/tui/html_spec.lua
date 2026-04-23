local Element = require('lean.tui').Element
local html = require 'tui.html'
local Tag = html.Tag

describe('tui.html', function()
  describe('<b>', function()
    it('renders bold text and applies bold highlight', function()
      local el = Tag.b { Element:new { text = 'bold' } }
      assert.is.equal('bold', el:to_string())
      assert.are.same({ 'tui.html.b' }, el.hlgroups)
    end)
  end)

  describe('<i>', function()
    it('renders italic text and applies italic highlight', function()
      local el = Tag.i { Element:new { text = 'italic' } }
      assert.is.equal('italic', el:to_string())
      assert.are.same({ 'tui.html.i' }, el.hlgroups)
    end)
  end)

  describe('<strong>', function()
    it('renders strong text as bold', function()
      local el = Tag.strong { Element:new { text = 'bold' } }
      assert.is.equal('bold', el:to_string())
      assert.are.same({ 'tui.html.b' }, el.hlgroups)
    end)
  end)

  describe('<em>', function()
    it('renders emphasized text as italic', function()
      local el = Tag.em { Element:new { text = 'italic' } }
      assert.is.equal('italic', el:to_string())
      assert.are.same({ 'tui.html.i' }, el.hlgroups)
    end)
  end)

  describe('<span>', function()
    it('renders span as inline container', function()
      local el = Tag.span { Element:new { text = 'span' } }
      assert.is.equal('span', el:to_string())
    end)
  end)

  describe('<p>', function()
    it('renders paragraph as plain container', function()
      local el = Tag.p { Element:new { text = 'para' } }
      assert.is.equal('para', el:to_string())
    end)
  end)

  describe('<br>', function()
    it('renders a line break', function()
      local el = Tag.br {}
      assert.is.equal('\n', el:to_string())
    end)

    it('renders children after the line break', function()
      local el = Tag.br { Element:new { text = 'after' } }
      assert.is.equal('\nafter', el:to_string())
    end)
  end)

  describe('<div>', function()
    it('renders div as block element with leading newline', function()
      local el = Tag.div { Element:new { text = 'inside' } }
      assert.is.equal('\ninside', el:to_string())
    end)

    it('renders nested tags inside div', function()
      local el = Tag.div {
        Tag.b { Element:new { text = 'bold' } },
        Tag.span { Element:new { text = 'plain' } },
      }
      assert.is.equal('\nboldplain', el:to_string())
    end)
  end)

  describe('<summary>', function()
    it('renders summary with marker', function()
      local el = Tag.summary { Element:new { text = 'sum' } }
      assert.is.equal('▼ sum', el:to_string())
    end)
  end)

  describe('<ul>', function()
    it('renders unordered list with items', function()
      local el = Tag.ul {
        Tag.li { Element:new { text = 'foo' } },
        Tag.li { Element:new { text = 'bar' } },
      }
      assert.is.equal('\n• foo\n• bar', el:to_string())
    end)

    it('renders nested unordered lists with indentation', function()
      local inner = Tag.ul({
        Tag.li { Element:new { text = 'nested' } },
      }, nil, { list_depth = 1 })
      local el = Tag.ul {
        Tag.li { Element:new { text = 'outer' } },
        Tag.li {
          Element:new { text = 'parent' },
          inner,
        },
      }
      assert.is.equal('\n• outer\n• parent\n  • nested', el:to_string())
    end)
  end)

  describe('<ol>', function()
    it('renders ordered list with items', function()
      local el = Tag.ol {
        Tag.li { Element:new { text = 'foo' } },
        Tag.li { Element:new { text = 'bar' } },
      }
      assert.is.equal('\n1. foo\n2. bar', el:to_string())
    end)

    it('renders nested ordered lists with indentation', function()
      local inner = Tag.ol({
        Tag.li { Element:new { text = 'nested' } },
      }, nil, { list_depth = 1 })
      local el = Tag.ol {
        Tag.li { Element:new { text = 'outer' } },
        Tag.li {
          Element:new { text = 'parent' },
          inner,
        },
      }
      assert.is.equal('\n1. outer\n2. parent\n  1. nested', el:to_string())
    end)
  end)

  describe('<li>', function()
    it('renders list item as plain text', function()
      local el = Tag.li { Element:new { text = 'item' } }
      assert.is.equal('item', el:to_string())
    end)
  end)

  describe('<code>', function()
    it('renders inline code with highlight', function()
      local el = Tag.code { Element:new { text = 'x + 1' } }
      assert.is.equal('x + 1', el:to_string())
      assert.are.same({ 'tui.html.code' }, el.hlgroups)
    end)
  end)

  describe('<hr>', function()
    it('renders a horizontal rule', function()
      local el = Tag.hr {}
      assert.is.equal('\n' .. string.rep('─', 40) .. '\n', el:to_string())
      assert.are.same({ 'tui.html.hr' }, el.hlgroups)
    end)
  end)

  describe('headings', function()
    for level = 1, 6 do
      it('renders <h' .. level .. '> as a block heading', function()
        local el = Tag['h' .. level] { Element:new { text = 'Title' } }
        assert.is.equal('\nTitle\n', el:to_string())
        assert.are.same({ 'tui.html.h' .. level }, el.hlgroups)
      end)
    end
  end)

  describe('<a>', function()
    it('renders link text with href as a clickable element', function()
      local el = Tag.a({ Element:new { text = 'click me' } }, { href = 'https://example.com' })
      assert.is.equal('click me', el:to_string())
      assert.is.equal('function', type(el.events.click))
      assert.are.same({ 'widgetLink' }, el.hlgroups)
    end)

    it('renders as plain container without href', function()
      local el = Tag.a({ Element:new { text = 'no link' } }, {})
      assert.is.equal('no link', el:to_string())
      assert.is.falsy(el.events.click)
    end)
  end)

  describe('render_table', function()
    it('renders a simple table with column alignment', function()
      local el = html.render_table {
        {
          cells = {
            Tag.td { Element:new { text = 'a' } },
            Tag.td { Element:new { text = 'b' } },
          },
          is_header = false,
        },
        {
          cells = {
            Tag.td { Element:new { text = 'cc' } },
            Tag.td { Element:new { text = 'd' } },
          },
          is_header = false,
        },
      }
      assert.is.equal('\na  │ b\ncc │ d', el:to_string())
    end)

    it('renders a table with header separator', function()
      local el = html.render_table {
        {
          cells = {
            Tag.th { Element:new { text = 'Name' } },
            Tag.th { Element:new { text = 'N' } },
          },
          is_header = true,
        },
        {
          cells = {
            Tag.td { Element:new { text = 'x' } },
            Tag.td { Element:new { text = '3' } },
          },
          is_header = false,
        },
      }
      -- Col widths: max(4,1)=4, max(1,1)=1.
      -- Separator: 4 dashes + ─┼─ + 1 dash.
      assert.is.equal('\nName │ N\n─────┼──\nx    │ 3', el:to_string())
    end)

    it('renders an empty table', function()
      local el = html.render_table {}
      assert.is.equal('', el:to_string())
    end)
  end)

  describe('inline styles', function()
    ---@param hlgroup string
    ---@return table
    local function get_hl(hlgroup)
      return vim.api.nvim_get_hl(0, { name = hlgroup })
    end

    it('applies color from a CSS string', function()
      local el = Tag.span({ Element:new { text = 'red' } }, { style = 'color: red' })
      assert.is.equal('red', el:to_string())
      local hl = get_hl(el.hlgroups[1])
      assert.is.equal('number', type(hl.fg))
    end)

    it('applies color from a JSON-style table', function()
      local el = Tag.span({ Element:new { text = 'blue' } }, { style = { color = 'blue' } })
      assert.is.equal('blue', el:to_string())
      local hl = get_hl(el.hlgroups[1])
      assert.is.equal('number', type(hl.fg))
    end)

    it('normalizes camelCase property names from JSON tables', function()
      local el = Tag.span(
        { Element:new { text = 'bg' } },
        { style = { backgroundColor = '#ff0000' } }
      )
      local hl = get_hl(el.hlgroups[1])
      assert.is.equal('number', type(hl.bg))
    end)

    it('applies bold from font-weight', function()
      local el = Tag.div({ Element:new { text = 'bold' } }, { style = 'font-weight: bold' })
      assert.is.True(get_hl(el.hlgroups[1]).bold)
    end)

    it('ignores unrecognized CSS properties', function()
      local el = Tag.span({ Element:new { text = 'plain' } }, { style = 'display: flex' })
      assert.is.equal('plain', el:to_string())
      assert.is.falsy(el.hlgroups)
    end)

    it('ignores unrecognized properties in JSON tables', function()
      local el = Tag.span(
        { Element:new { text = 'plain' } },
        { style = { ['white-space'] = 'pre-wrap' } }
      )
      assert.is.equal('plain', el:to_string())
      assert.is.falsy(el.hlgroups)
    end)

    it('applies multiple style properties', function()
      local el = Tag.span(
        { Element:new { text = 'styled' } },
        { style = 'color: blue; font-style: italic; text-decoration: underline' }
      )
      assert.is.equal('styled', el:to_string())
      local hl = get_hl(el.hlgroups[1])
      assert.is.equal('number', type(hl.fg))
      assert.is.True(hl.italic)
      assert.is.True(hl.underline)
    end)

    it('reuses hlgroups for identical styles', function()
      local el1 = Tag.span({ Element:new { text = 'a' } }, { style = 'color: #123456' })
      local el2 = Tag.span({ Element:new { text = 'b' } }, { style = 'color: #123456' })
      assert.are.same(el1.hlgroups, el2.hlgroups)
    end)
  end)

  describe('unsupported tags', function()
    it('renders unsupported tags as visible fallback', function()
      local el = Tag.unknown { Element:new { text = 'child' } }
      assert.is.equal('<unknown>child', el:to_string())
    end)
  end)
end)
