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
    it('renders paragraph as block element', function()
      local el = Tag.p { Element:new { text = 'para' } }
      assert.is.equal('para', el:to_string())
      assert.is.True(el.is_block)
    end)

    it('starts on a new line when following inline content', function()
      local el = Element:new {
        children = {
          Element:new { text = 'before' },
          Tag.p { Element:new { text = 'block' } },
        },
      }
      assert.is.equal('before\nblock', el:to_string())
    end)

    it('collapses margins with parent block elements', function()
      local el = Tag.div { Tag.p { Element:new { text = 'nested' } } }
      assert.is.equal('nested', el:to_string())
    end)

    it('forces inline siblings onto a new line', function()
      local el = Element:new {
        children = {
          Tag.p { Element:new { text = 'block' } },
          Tag.span { Element:new { text = 'after' } },
        },
      }
      assert.is.equal('block\nafter', el:to_string())
    end)

    it('drops whitespace-only text between block siblings', function()
      local el = Element:new {
        children = {
          Tag.p { Element:new { text = 'first' } },
          Element:new { text = ' ' },
          Tag.p { Element:new { text = 'second' } },
        },
      }
      assert.is.equal('first\nsecond', el:to_string())
    end)

    it('strips leading whitespace from inline text following a block', function()
      local el = Element:new {
        children = {
          Tag.p { Element:new { text = 'block' } },
          Element:new { text = ' more text' },
        },
      }
      assert.is.equal('block\nmore text', el:to_string())
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
    it('renders div as block element', function()
      local el = Tag.div { Element:new { text = 'inside' } }
      assert.is.equal('inside', el:to_string())
      assert.is.True(el.is_block)
    end)

    it('renders nested tags inside div', function()
      local el = Tag.div {
        Tag.b { Element:new { text = 'bold' } },
        Tag.span { Element:new { text = 'plain' } },
      }
      assert.is.equal('boldplain', el:to_string())
    end)
  end)

  describe('<summary>', function()
    it('renders summary with marker', function()
      local el = Tag.summary { Element:new { text = 'sum' } }
      assert.is.equal('sum', el:to_string())
    end)
  end)

  describe('<ul>', function()
    it('renders unordered list with items', function()
      local el = Tag.ul {
        Tag.li { Element:new { text = 'foo' } },
        Tag.li { Element:new { text = 'bar' } },
      }
      assert.is.equal('• foo\n• bar', el:to_string())
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
      assert.is.equal('• outer\n• parent\n  ◦ nested', el:to_string())
    end)
  end)

  describe('<ol>', function()
    it('renders ordered list with items', function()
      local el = Tag.ol {
        Tag.li { Element:new { text = 'foo' } },
        Tag.li { Element:new { text = 'bar' } },
      }
      assert.is.equal('1. foo\n2. bar', el:to_string())
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
      assert.is.equal('1. outer\n2. parent\n  1. nested', el:to_string())
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
      assert.is.equal(string.rep('─', 40), el:to_string())
      assert.are.same({ 'tui.html.hr' }, el.hlgroups)
      assert.is.True(el.is_block)
    end)
  end)

  describe('headings', function()
    for level = 1, 6 do
      it('renders <h' .. level .. '> as a block heading', function()
        local el = Tag['h' .. level] { Element:new { text = 'Title' } }
        assert.is.equal('Title', el:to_string())
        assert.are.same({ 'tui.html.h' .. level }, el.hlgroups)
        assert.is.True(el.is_block)
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

  describe('<del>', function()
    it('renders strikethrough text', function()
      local el = Tag.del { Element:new { text = 'removed' } }
      assert.is.equal('removed', el:to_string())
      assert.are.same({ 'tui.html.del' }, el.hlgroups)
    end)
  end)

  describe('<s>', function()
    it('renders strikethrough text as an alias for del', function()
      local el = Tag.s { Element:new { text = 'old' } }
      assert.is.equal('old', el:to_string())
      assert.are.same({ 'tui.html.del' }, el.hlgroups)
    end)
  end)

  describe('<u>', function()
    it('renders underlined text', function()
      local el = Tag.u { Element:new { text = 'underlined' } }
      assert.is.equal('underlined', el:to_string())
      assert.are.same({ 'tui.html.u' }, el.hlgroups)
    end)
  end)

  describe('<ins>', function()
    it('renders underlined text as an alias for u', function()
      local el = Tag.ins { Element:new { text = 'inserted' } }
      assert.is.equal('inserted', el:to_string())
      assert.are.same({ 'tui.html.u' }, el.hlgroups)
    end)
  end)

  describe('<mark>', function()
    it('renders highlighted text', function()
      local el = Tag.mark { Element:new { text = 'highlighted' } }
      assert.is.equal('highlighted', el:to_string())
      assert.are.same({ 'tui.html.mark' }, el.hlgroups)
    end)
  end)

  describe('<blockquote>', function()
    it('renders with vertical bar prefix', function()
      local el = Tag.blockquote { Element:new { text = 'quoted' } }
      assert.is.equal('│ quoted', el:to_string())
      assert.is.True(el.is_block)
    end)

    it('prefixes every line with the bar', function()
      local el = Tag.blockquote { Element:new { text = 'line1\nline2\nline3' } }
      assert.is.equal('│ line1\n│ line2\n│ line3', el:to_string())
    end)

    it('renders nested blockquotes with stacked bars', function()
      local el = Tag.blockquote {
        Tag.blockquote { Element:new { text = 'deep' } },
      }
      assert.is.equal('│ │ deep', el:to_string())
    end)
  end)

  describe('<sub>', function()
    it('renders subscript text inline', function()
      local el = Tag.sub { Element:new { text = '2' } }
      assert.is.equal('₍2₎', el:to_string())
    end)
  end)

  describe('<sup>', function()
    it('renders superscript text inline', function()
      local el = Tag.sup { Element:new { text = 'n' } }
      assert.is.equal('⁽n⁾', el:to_string())
    end)
  end)

  describe('<ol start=N>', function()
    it('starts numbering at the given value', function()
      local el = Tag.ol({
        Tag.li { Element:new { text = 'third' } },
        Tag.li { Element:new { text = 'fourth' } },
      }, { start = '3' })
      assert.is.equal('3. third\n4. fourth', el:to_string())
    end)
  end)

  describe('<style>', function()
    it('renders as empty, hiding CSS content', function()
      local el = Tag.style { Element:new { text = 'body { color: red }' } }
      assert.is.equal('', el:to_string())
    end)
  end)

  describe('<script>', function()
    it('renders as empty, hiding script content', function()
      local el = Tag.script { Element:new { text = 'alert("hi")' } }
      assert.is.equal('', el:to_string())
    end)
  end)

  describe('list items with block children', function()
    it('strips leading newlines from block elements inside list items', function()
      local el = Tag.ul {
        Tag.li { Tag.p { Element:new { text = 'inside p' } } },
        Tag.li { Tag.div { Element:new { text = 'inside div' } } },
      }
      assert.is.equal('• inside p\n• inside div', el:to_string())
    end)
  end)

  describe('inline styles', function()
    ---@param hlgroup string
    ---@return table
    local function get_hl(hlgroup)
      return vim.api.nvim_get_hl(0, { name = hlgroup })
    end

    it('applies color', function()
      local el = html._styled(Element:new { text = 'red' }, { style = { color = 'red' } })
      assert.is.equal('red', el:to_string())
      local hl = get_hl(el.hlgroups[1])
      assert.is.equal('number', type(hl.fg))
    end)

    it('normalizes camelCase property names', function()
      local el =
        html._styled(Element:new { text = 'bg' }, { style = { backgroundColor = '#ff0000' } })
      local hl = get_hl(el.hlgroups[1])
      assert.is.equal('number', type(hl.bg))
    end)

    it('applies bold from font-weight keyword', function()
      local el =
        html._styled(Element:new { text = 'bold' }, { style = { ['font-weight'] = 'bold' } })
      assert.is.True(get_hl(el.hlgroups[1]).bold)
    end)

    it('applies bold from numeric font-weight >= 700', function()
      local el =
        html._styled(Element:new { text = 'bold' }, { style = { ['font-weight'] = '700' } })
      assert.is.True(get_hl(el.hlgroups[1]).bold)
    end)

    it('does not apply bold from numeric font-weight < 700', function()
      local el =
        html._styled(Element:new { text = 'normal' }, { style = { ['font-weight'] = '400' } })
      assert.is.falsy(el.hlgroups)
    end)

    it('applies strikethrough from text-decoration-line', function()
      local el = html._styled(
        Element:new { text = 'struck' },
        { style = { ['text-decoration-line'] = 'line-through' } }
      )
      assert.is.True(get_hl(el.hlgroups[1]).strikethrough)
    end)

    it('ignores unrecognized CSS properties', function()
      local el = html._styled(Element:new { text = 'plain' }, { style = { display = 'flex' } })
      assert.is.equal('plain', el:to_string())
      assert.is.falsy(el.hlgroups)
    end)

    it('ignores unrecognized properties', function()
      local el =
        html._styled(Element:new { text = 'plain' }, { style = { ['white-space'] = 'pre-wrap' } })
      assert.is.equal('plain', el:to_string())
      assert.is.falsy(el.hlgroups)
    end)

    it('applies multiple style properties', function()
      local el = html._styled(Element:new { text = 'styled' }, {
        style = {
          color = 'blue',
          ['font-style'] = 'italic',
          ['text-decoration'] = 'underline',
        },
      })
      assert.is.equal('styled', el:to_string())
      local hl = get_hl(el.hlgroups[1])
      assert.is.equal('number', type(hl.fg))
      assert.is.True(hl.italic)
      assert.is.True(hl.underline)
    end)

    it('reuses hlgroups for identical styles', function()
      local el1 = html._styled(Element:new { text = 'a' }, { style = { color = '#123456' } })
      local el2 = html._styled(Element:new { text = 'b' }, { style = { color = '#123456' } })
      assert.are.same(el1.hlgroups, el2.hlgroups)
    end)

    it('composes with existing hlgroups from tag handlers', function()
      local el =
        html._styled(Tag.b { Element:new { text = 'bold red' } }, { style = { color = '#abcdef' } })
      assert.is.equal(2, #el.hlgroups)
      assert.is.equal('tui.html.b', el.hlgroups[1])
      assert.is.equal('number', type(get_hl(el.hlgroups[2]).fg))
    end)
  end)

  describe('parse_css', function()
    it('parses CSS strings into property tables', function()
      local props = html.parse_css 'color: red; font-weight: bold'
      assert.are.same({ color = 'red', ['font-weight'] = 'bold' }, props)
    end)

    it('handles camelCase properties in CSS strings', function()
      local props = html.parse_css 'background-color: blue'
      assert.are.same({ ['background-color'] = 'blue' }, props)
    end)
  end)

  describe('is_hidden', function()
    it('detects display: none', function()
      assert.is.True(html.is_hidden { display = 'none' })
    end)

    it('detects visibility: hidden', function()
      assert.is.True(html.is_hidden { visibility = 'hidden' })
    end)

    it('detects opacity: 0', function()
      assert.is.True(html.is_hidden { opacity = '0' })
      assert.is.True(html.is_hidden { opacity = 0 })
    end)

    it('returns false for visible elements', function()
      assert.is.False(html.is_hidden { display = 'flex' })
      assert.is.False(html.is_hidden { color = 'red' })
      assert.is.False(html.is_hidden { opacity = '0.5' })
      assert.is.False(html.is_hidden { display = 'block' })
    end)
  end)

  describe('unsupported tags', function()
    it('renders unsupported tags as visible fallback', function()
      local el = Tag.unknown { Element:new { text = 'child' } }
      assert.is.equal('<unknown>child', el:to_string())
    end)
  end)
end)
