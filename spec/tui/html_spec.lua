local Element = require('lean.tui').Element
local Tag = require('tui.html').Tag

describe('tui.html', function()
  describe('<b>', function()
    it('renders bold text and applies bold highlight', function()
      local el = Tag.b { Element:new { text = 'bold' } }
      assert.is.equal('bold', el:to_string())
      assert.is.equal('tui.html.b', el.hlgroup)
    end)
  end)

  describe('<span>', function()
    it('renders span as plain container', function()
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

  describe('<div>', function()
    it('renders div as block with newline', function()
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

  describe('<details>', function()
    it('renders details as titled block', function()
      local el = Tag.details { Element:new { text = 'body' } }
      assert.is.equal('body', el:to_string())
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
  end)

  describe('<ol>', function()
    it('renders ordered list with items', function()
      local el = Tag.ol {
        Tag.li { Element:new { text = 'foo' } },
        Tag.li { Element:new { text = 'bar' } },
      }
      assert.is.equal('\n1. foo\n2. bar', el:to_string())
    end)
  end)

  describe('<li>', function()
    it('renders list item as plain text', function()
      local el = Tag.li { Element:new { text = 'item' } }
      assert.is.equal('item', el:to_string())
    end)
  end)

  describe('unsupported tags', function()
    it('renders unsupported tags as visible fallback', function()
      local el = Tag.unknown { Element:new { text = 'child' } }
      assert.is.equal('<unknown>child', el:to_string())
    end)
  end)
end)
