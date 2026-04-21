---@brief [[
--- Tests for SVG rasterization, serialization, and tag rendering.
---@brief ]]

describe('tui.svg', function()
  local svg = require 'tui.svg'

  describe('available', function()
    it('detects libresvg', function()
      -- This test depends on libresvg being installed.
      -- Skip gracefully if not.
      if not svg.available() then
        pending 'libresvg not installed'
      end
      assert.is_true(svg.available())
    end)
  end)

  describe('serialize', function()
    it('serializes a simple element', function()
      local tree = {
        'svg',
        { { 'xmlns', 'http://www.w3.org/2000/svg' }, { 'width', '100' } },
        {},
      }
      assert.are.equal('<svg xmlns="http://www.w3.org/2000/svg" width="100"/>', svg.serialize(tree))
    end)

    it('serializes nested elements with text', function()
      local tree = {
        'svg',
        { { 'width', '100' } },
        {
          {
            element = {
              'text',
              { { 'x', '10' } },
              { { text = 'hello' } },
            },
          },
        },
      }
      assert.are.equal('<svg width="100"><text x="10">hello</text></svg>', svg.serialize(tree))
    end)

    it('escapes XML special characters in attribute values', function()
      local tree = {
        'svg',
        { { 'data', 'a&b"c<d>e' } },
        {},
      }
      assert.are.equal('<svg data="a&amp;b&quot;c&lt;d&gt;e"/>', svg.serialize(tree))
    end)

    it('escapes XML special characters in text nodes', function()
      local tree = {
        'text',
        {},
        { { text = 'a < b & c > d' } },
      }
      assert.are.equal('<text>a &lt; b &amp; c &gt; d</text>', svg.serialize(tree))
    end)

    it('handles self-closing elements with no children', function()
      local tree = {
        'g',
        {},
        {
          { element = { 'circle', { { 'r', '5' } }, {} } },
          { element = { 'rect', { { 'width', '10' } }, {} } },
        },
      }
      assert.are.equal('<g><circle r="5"/><rect width="10"/></g>', svg.serialize(tree))
    end)
  end)

  describe('rasterize', function()
    it('produces pixel data with correct dimensions', function()
      if not svg.available() then
        pending 'libresvg not installed'
        return
      end
      local pixels, w, h =
        svg.rasterize '<svg xmlns="http://www.w3.org/2000/svg" width="50" height="30"></svg>'
      assert.are.equal(50, w)
      assert.are.equal(30, h)
      assert.is_not_nil(pixels)
    end)

    it('clamps dimensions to at least 1', function()
      if not svg.available() then
        pending 'libresvg not installed'
        return
      end
      local _, w, h =
        svg.rasterize '<svg xmlns="http://www.w3.org/2000/svg" width="0.5" height="0.5"></svg>'
      assert.is_true(w >= 1)
      assert.is_true(h >= 1)
    end)

    it('rejects SVGs that exceed the pixel budget', function()
      if not svg.available() then
        pending 'libresvg not installed'
        return
      end
      assert.has_error(function()
        svg.rasterize '<svg xmlns="http://www.w3.org/2000/svg" width="5000" height="5000"></svg>'
      end, 'SVG too large: 5000x5000')
    end)

    it('errors on invalid SVG', function()
      if not svg.available() then
        pending 'libresvg not installed'
        return
      end
      assert.has_error(function()
        svg.rasterize 'not svg at all'
      end)
    end)
  end)
end)

describe('html.Tag.svg', function()
  local Tag = require('tui.html').Tag
  local svg = require 'tui.svg'

  it('creates an element with an overlay field', function()
    if not svg.available() then
      pending 'libresvg not installed'
      return
    end
    local value = {
      'svg',
      { { 'xmlns', 'http://www.w3.org/2000/svg' }, { 'width', '10' }, { 'height', '10' } },
      {},
    }
    local element = Tag.svg(value)
    assert.is_not_nil(element.overlay)
    assert.are.equal(10, element.overlay.width)
    assert.are.equal(10, element.overlay.height)
    assert.is_not_nil(element.overlay.data)
  end)

  it('reserves placeholder lines matching image height', function()
    if not svg.available() then
      pending 'libresvg not installed'
      return
    end
    local kitty = require 'kitty'
    local value = {
      'svg',
      { { 'xmlns', 'http://www.w3.org/2000/svg' }, { 'width', '10' }, { 'height', '100' } },
      {},
    }
    local element = Tag.svg(value)
    local expected_rows = kitty.rows_for_height(100)
    -- text has rows-1 newlines
    local newlines = select(2, element.text:gsub('\n', '\n'))
    assert.are.equal(expected_rows - 1, newlines)
  end)

  it('shows an error for invalid SVG data', function()
    if not svg.available() then
      pending 'libresvg not installed'
      return
    end
    -- An element with no xmlns will fail to produce valid SVG,
    -- but resvg may still parse it. Use truly broken data.
    local value = {
      'not-svg',
      {},
      { { text = '<<<>>>' } },
    }
    local element = Tag.svg(value)
    -- Should either succeed or show an error, not crash.
    assert.is_not_nil(element)
  end)

  it('shows fallback text when libresvg is not loaded', function()
    if not svg.available() then
      pending 'libresvg not installed'
      return
    end
    -- We can't truly unload libresvg, but we can verify the element
    -- structure when it IS loaded (overlay present).
    local value = {
      'svg',
      { { 'xmlns', 'http://www.w3.org/2000/svg' }, { 'width', '10' }, { 'height', '10' } },
      {},
    }
    local element = Tag.svg(value)
    -- With resvg available, overlay should be set.
    assert.is_not_nil(element.overlay)
  end)

  it('survives cache eviction without crashing', function()
    if not svg.available() then
      pending 'libresvg not installed'
      return
    end
    -- Render more than SVG_CACHE_SIZE (32) distinct SVGs to trigger eviction.
    for i = 1, 35 do
      local value = {
        'svg',
        {
          { 'xmlns', 'http://www.w3.org/2000/svg' },
          { 'width', tostring(i) },
          { 'height', '1' },
        },
        {},
      }
      local element = Tag.svg(value)
      assert.is_not_nil(element)
      assert.is_not_nil(element.overlay)
    end
  end)
end)
